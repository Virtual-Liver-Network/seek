#Default values required for the automated unit, functional and integration testing to behave as expected.
SEEK::Application.configure do
  if Rails.env.test?
    silence_warnings do
      Settings.defaults[:project_hierarchy_enabled] = true
      Settings.defaults[:is_virtualliver] = false
      Settings.defaults[:application_title] = 'The Sysmo SEEK'
      Settings.defaults[:project_name] = 'Sysmo'
      Settings.defaults[:project_title] = 'The Sysmo Consortium'

      Settings.defaults[:noreply_sender] ="no-reply@sysmo-db.org"

      Settings.defaults[:crossref_api_email] = "sowen@cs.man.ac.uk"

      Settings.defaults[:jws_enabled] = true
      Settings.defaults[:events_enabled] = true
      Settings.defaults[:jws_online_root] = "http://jws.sysmo-db.org"

      Settings.defaults[:email_enabled] = true
      Settings.defaults[:solr_enabled] = false
      Settings.defaults[:publish_button_enabled] = true
      Settings.defaults[:auth_lookup_enabled] = false
      Settings.defaults[:sample_parser_enabled] = true
      Settings.defaults[:project_browser_enabled] = true
      Settings.defaults[:experimental_features_enabled] = true
      Settings.defaults[:filestore_path] = "tmp/testing-filestore"

      Settings.defaults[:bioportal_api_key]="fish"

      Settings.defaults[:technology_type_ontology_file]= "file:#{Rails.root}/test/fixtures/files/JERM-test.rdf"
      Settings.defaults[:modelling_analysis_type_ontology_file]="file:#{Rails.root}/test/fixtures/files/JERM-test.rdf"
      Settings.defaults[:assay_type_ontology_file]="file:#{Rails.root}/test/fixtures/files/JERM-test.rdf"

    end
  end
end

