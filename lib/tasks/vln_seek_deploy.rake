require 'rubygems'
require 'rake'
require 'active_record/fixtures'
require 'uuidtools'
require 'colorize'


namespace :vln_seek do

  task :upgrade_tasks => [
      :environment,
      :update_scales,
      "seek:update_admin_assigned_roles",
      :update_assay_and_technology_types,
      "seek:repopulate_missing_publication_book_titles",
      :increase_sheet_empty_rows,
      "seek:remove_invalid_group_memberships",
      "seek:clear_filestore_tmp",
      :clean_up_sop_specimens,
      :update_jws_online_root,
      :update_bioportal_concepts,
      :drop_solr_index,
      "seek:repopulate_auth_lookup_tables",
  ]
  task :update_scales => [
      :environment,
      "seek_scales:vl_scales",
      "seek_scales:scalings_to_annotations",
  ]
  task :update_assay_and_technology_types => [
      :environment,
      :correct_misspellt_assay_type,
      :add_old_suggested_assay_types,
      :add_old_suggested_technology_types,
      "seek:resynchronise_assay_types",
      "seek:resynchronise_technology_types",
  ]

  task(:backup, :environment) do
    #treatments??

  end

  desc("deploy VLN SEEK with new merged version ")
  task(:deploy => [:environment, :backup, "db:migrate", "db:sessions:clear", "tmp:clear"]) do

    solr=Seek::Config.solr_enabled

    Seek::Config.solr_enabled=false

    Rake::Task["vln_seek:upgrade_tasks"].invoke

    Seek::Config.solr_enabled = solr

    if (solr)
      Rake::Task["seek:reindex_all"].invoke
    end

    puts "Upgrade completed successfully"
  end


  #new added tasks for deploy

  task(:correct_misspellt_assay_type => :environment) do
    #fix spelling error in earlier seed data
    type = AssayType.find_by_title("flux balanace analysis")
    unless type.nil?
      type.title = "flux balance analysis"
      type.save
    end
  end

  task(:add_old_suggested_assay_types => :environment) do

    labels_in_ontology = SuggestedAssayType.base_ontology_hash_by_label.keys
    titles_in_seek = AssayType.all.delete_if { |type| type.title == "assay types" }.map { |t| t.title.downcase }


    label_map = YAML::load_file(File.join(Rails.root, "config", "default_data", "assay_types_label_mappings.yml"))
    titles_in_seek.each_with_index do |title, index|
      titles_in_seek[index] = label_map[title] if label_map[title]
    end

    suggested_labels = titles_in_seek - labels_in_ontology

    suggested_labels.each do |label|
      assay_type = AssayType.find_by_title(label)
      parent_title = assay_type.parents.first.title.downcase
      parent_uri = if labels_in_ontology.include?(parent_title)
                     SuggestedAssayType.base_ontology_hash_by_label[parent_title].uri.to_s
                   elsif labels_in_ontology.include?(label_map[parent_title])
                     SuggestedAssayType.base_ontology_hash_by_label[label_map[parent_title]].uri.to_s
                   else
                     nil
                   end
      suggested_type = SuggestedAssayType.where(label: label, parent_uri: parent_uri).first_or_create!
      puts "suggested assay type #{label} was created, parent_uri: #{parent_uri}".red
      #update assay type uri in assays
      assay_type.assays.each do |assay|
        assay.assay_type_uri = suggested_type.uri
        disable_authorization_checks do
          assay.save(:validate => false)
        end
        puts "assay(#{assay.title}) was updated, assay_type_uri: #{suggested_type.uri}".red
      end
    end
  end

  task(:add_old_suggested_technology_types => :environment) do

    labels_in_ontology = SuggestedTechnologyType.base_ontology_hash_by_label.keys
    titles_in_seek = TechnologyType.all.delete_if { |type| type.title.blank? }.map { |t| t.title.downcase }


    label_map = YAML::load_file(File.join(Rails.root, "config", "default_data", "technology_types_label_mappings.yml"))
    titles_in_seek.each_with_index do |title, index|
      titles_in_seek[index] = label_map[title] if label_map[title]
    end
    suggested_labels = titles_in_seek - labels_in_ontology
    suggested_labels.each do |label|
      technology_type = TechnologyType.find_by_title(label)
      parent_title = technology_type.parents.first.title.downcase
      parent_uri = if labels_in_ontology.include?(parent_title)
                     SuggestedTechnologyType.base_ontology_hash_by_label[parent_title].uri.to_s
                   elsif labels_in_ontology.include?(label_map[parent_title])
                     SuggestedTechnologyType.base_ontology_hash_by_label[label_map[parent_title]].uri.to_s
                   else
                     nil
                   end
      suggested_type = SuggestedTechnologyType.where(label: label, parent_uri: parent_uri).first_or_create!
      puts "suggested technology type #{label} was created, parent_uri: #{parent_uri}".red
      technology_type.assays.each do |assay|
        assay.technology_type_uri = suggested_type.uri
        disable_authorization_checks do
          assay.save(:validate => false)
        end
        puts "assay(#{assay.title}) was updated, technology_type_uri: #{suggested_type.uri}".red
      end
    end
  end

  #old upgrade tasks from v0.16.3 to v0.22.0

  task(:clean_up_sop_specimens => :environment) do
    broken = SopSpecimen.all.select { |ss| ss.sop.nil? || ss.specimen.nil? }
    disable_authorization_checks do
      broken.each { |b| b.destroy }
    end
  end

  task(:update_jws_online_root => :environment) do
    Seek::Config.jws_online_root = 'https://jws.sysmo db.org/'
  end

  desc("Increase the min rows from 10 to 35")
  task(:increase_sheet_empty_rows => :environment) do
    worksheets = Worksheet.all.compact
    min_rows = Seek::Data::SpreadsheetExplorerRepresentation::MIN_ROWS
    worksheets.each do |ws|
      if ws.last_row < min_rows
        ws.last_row = min_rows
        ws.save
      end
    end
  end

  task(:update_bioportal_concepts => :environment) do
    BioportalConcept.all.each do |concept|
      uri = concept.concept_uri
      unless uri.include?("purl")
        uri = uri.gsub(":", "_")
        concept.concept_uri = "http://purl.obolibrary.org/obo/#{uri}"
      end
      concept.ontology_id = "NCBITAXON"
      concept.cached_concept_yaml=nil
      concept.save!
    end
  end

  task(:drop_solr_index => :environment) do
    dir = File.join(Rails.root, "solr", "data")
    if File.exists?(dir)
      FileUtils.remove_dir(dir)
    end
  end


end
