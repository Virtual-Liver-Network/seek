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

  task :update_assay_and_technology_types => [
      :environment,
       :create_new_assay_types,
       :create_new_technology_types,
      #"seek:resynchronise_assay_types",
      #"seek:resynchronise_technology_types",
  ]

  task :backup => [
     :environment,
     :dump_organisms_strains_data
  ]

  task :update_scales => [
       :environment,
       "seek_scales:vl_scales",
       "seek_scales:scalings_to_annotations",
   ]

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

  task(:dump_organisms_strains_data => :environment) do
    File.open("config/default_data/organisms.yml", "w") do |f|
      f.write Organism.all.map{|o|o.attributes.reject{|k,v| k=="created_at" || k == "updated_at"}}.to_yaml
    end
    File.open("config/default_data/strains.yml", "w") do |f|
      f.write Strain.all.map{|s|s.attributes.reject{|k,v| k=="created_at" || k == "updated_at"}}.to_yaml
    end

  end


   task(:create_new_assay_types => :environment) do
     new_assay_type_edges = YAML.load(File.read("config/default_data/new_assay_types.yml"))
     new_assay_type_edges.each do |label, attrs|
       parent_uri = Array(attrs["parent_uris"]).first
       assay_ids = Array(attrs["assay_ids"])
       suggested_type_id = nil
       if label.downcase == "cDNA microarray".downcase
         mapped_label = "transcriptional profiling"
         ontology_class =  SuggestedAssayType.new.ontology_readers.map{|r|r.class_hierarchy.hash_by_label[mapped_label.downcase]}.compact.first
         type_uri = ontology_class.try(:uri).try(:to_s)
       else
         suggested_type = SuggestedAssayType.create!(label: label, parent_uri: parent_uri)
         type_uri = suggested_type.try(:uri)
         suggested_type_id = suggested_type.try(:id)
       end
       assay_ids.each do |a_id|
         if assay = Assay.find(a_id)
           assay.assay_type_uri = type_uri
           assay.suggested_assay_type_id = suggested_type_id if suggested_type_id
           disable_authorization_checks do
             assay.save
           end
         end
       end

     end


   end

   task(:create_new_technology_types => :environment) do
     new_technology_type_edges = YAML.load(File.read("config/default_data/new_technology_types.yml"))
         new_technology_type_edges.each do |label, attrs|
           parent_uri = Array(attrs["parent_uris"]).first
           assay_ids = Array(attrs["assay_ids"])
           suggested_type_id = nil
           if label.downcase == "cDNA microarray".downcase
             mapped_label = "microarray"
             ontology_class = SuggestedAssayType.new.ontology_readers.map{|r|r.class_hierarchy.hash_by_label[mapped_label.downcase]}.compact.first
             type_uri = ontology_class.try(:uri).try(:to_s)
           else
             suggested_type = SuggestedTechnologyType.create!(label: label, parent_uri: parent_uri)
             type_uri = suggested_type.try(:uri)
             suggested_type_id = suggested_type.try(:id)
           end
           assay_ids.each do |a_id|
             if assay = Assay.find(a_id)
               assay.technology_type_uri = type_uri
               assay.suggested_technology_type_id = suggested_type_id if suggested_type_id
               disable_authorization_checks do
                 assay.save
               end
             end
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
