require 'rubygems'
require 'rake'
require 'active_record/fixtures'
require 'uuidtools'
require 'colorize'


namespace :vln_seek do

  task :upgrade_tasks => [
      :environment,
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
      "seek:resynchronise_assay_types",
      "seek:resynchronise_technology_types",
  ]

  task :backup => [
     :environment,
    :update_scales,
    :dump_existing_suggested_assay_types,
    :dump_existing_suggested_technology_types
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

  desc("dump existing assay types in VLN but not in the core of JERM ontology as suggested types")
   task(:dump_existing_suggested_assay_types => :environment) do
     new_assay_type_edges= {}
     new_assay_type_titles = ["cDNA microarray", "Protein activation", "DNA synthesis", "lipidomics", "new metabolomic assay"]
     # "cDNA microarray" mapped to "transcriptional profiling" ??
     new_assay_type_titles.each do |title|
       new_assay_type_edges[title] = {}
       type = AssayType.where(title: title).first
       parents_labels = type.parents.map(&:title).map{|label| label == "experimental assay type" ? "experimental assay" : label}
       new_assay_type_edges[title]["parents_labels"] = parents_labels
       new_assay_type_edges[title]["parents_uris"] = parents_labels.map{|pl| SuggestedAssayType.base_ontology_hash_by_label[pl.downcase].try(:uri).try(&:to_s)}
       new_assay_type_edges[title]["assay_ids"] = type.assays.map(&:id)
     end
     File.open('config/default_data/new_assay_types.yml', "w") { |f|
       f.write new_assay_type_edges.to_yaml
     }

   end

   desc("dump existing technology types in VLN but not in the core of JERM ontology as suggested types")
   task(:dump_existing_suggested_technology_types => :environment) do
     new_technology_type_edges= {}
         new_technology_type_titles = ["cdna microarray", "affymetrix genechip oligonucleotide arrays", "fluidigm high-throughput taqman platform", "western blotting", "fluorescence", "quantitative immunoblotting"]
        # cdna microarray: microarray
         new_technology_type_titles.each do |title|
           new_technology_type_edges[title] = {}
           type = TechnologyType.where(title: title).first
           parents_labels = type.parents.map(&:title).map{|label| label == "technology" ? "technology type" : label}
           new_technology_type_edges[title]["parents_labels"] = parents_labels
           new_technology_type_edges[title]["parents_uris"] = parents_labels.map{|pl| SuggestedTechnologyType.base_ontology_hash_by_label[pl.downcase].try(:uri).try(&:to_s)}
           new_technology_type_edges[title]["assay_ids"] = type.assays.map(&:id)
         end
         File.open('config/default_data/new_technology_types.yml', "w") { |f|
           f.write new_technology_type_edges.to_yaml
         }
   end

   task(:create_new_assay_types => :environment) do
     new_assay_type_edges = YAML.load(File.read("config/default_data/new_assay_types.yml"))
     new_assay_type_edges.each do |label, attrs|
       parent_uri = Array(attrs["parent_uris"]).first
       assay_ids = Array(attrs["assay_ids"])
       if label.downcase == "cDNA microarray".downcase
         mapped_label = "transcriptional profiling"
         ontology_class = SuggestedAssayType.base_ontology_hash_by_label[mapped_label.downcase]
         type_uri = ontology_class.try(:uri).try(:to_s)
         type_label = ontology_class.try(:label)
       else
         suggested_type = SuggestedAssayType.create!(label: label, parent_uri: parent_uri)
         type_uri = suggested_type.try(:uri)
         type_label = label
       end
       assay_ids.each do |a_id|
         if assay = Assay.find(a_id)
           assay.assay_type_uri = type_uri
           assay.assay_type_label = type_label
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
           if label.downcase == "cDNA microarray".downcase
             mapped_label = "microarray"
             ontology_class = SuggestedTechnologyType.base_ontology_hash_by_label[mapped_label.downcase]
             type_uri = ontology_class.try(:uri).try(:to_s)
             type_label = ontology_class.try(:label)
           else
             suggested_type = SuggestedTechnologyType.create!(label: label, parent_uri: parent_uri)
             type_uri = suggested_type.try(:uri)
             type_label = label
           end
           assay_ids.each do |a_id|
             if assay = Assay.find(a_id)
               assay.technology_type_uri = type_uri
               assay.technology_type_label = type_label
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
