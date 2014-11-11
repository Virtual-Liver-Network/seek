require 'rubygems'
require 'rake'
require 'rdoc/task'

namespace :doc do
  desc "Generate SEEK technical documentation"
  RDoc::Task.new("seek") { |rdoc|
    rdoc.rdoc_dir = 'doc/seek'
    rdoc.template = ENV['template'] if ENV['template']
    rdoc.title = ENV['title'] || "SEEK Technical Guide"
    rdoc.options << '--line-numbers'
    rdoc.options << '--charset' << 'utf-8'

    rdoc.rdoc_files.include('doc/README')

    rdoc.rdoc_files.include('doc/CREDITS')
    rdoc.rdoc_files.include('doc/INSTALL')
    rdoc.rdoc_files.include('doc/INSTALL-PRODUCTION')
    rdoc.rdoc_files.include('doc/INSTALL-ON-A-SUBURI')
    rdoc.rdoc_files.include('doc/OTHER-DISTRIBUTIONS')
    rdoc.rdoc_files.include('doc/UPGRADING')
    rdoc.rdoc_files.include('doc/EARLIER-UPGRADES')
    rdoc.rdoc_files.include('doc/UPGRADING-TO-0-18')
    rdoc.rdoc_files.include('doc/BACKUPS')
    rdoc.rdoc_files.include('doc/ADMINISTRATION')
    rdoc.rdoc_files.include('doc/SETTING-UP-VIRTUOSO')
    rdoc.rdoc_files.include('doc/CONTRIBUTING_TO_SEEK')
    rdoc.rdoc_files.include('doc/CONTACTING_US')

    rdoc.rdoc_files.include('lib/seek/rdf/rdf_repository.rb')
    rdoc.rdoc_files.include('lib/seek/rdf/rdf_repository_storage.rb')
    rdoc.rdoc_files.include('lib/seek/rdf/rdf_file_storage.rb')
    rdoc.rdoc_files.include('lib/seek/rdf/virtuoso_repository.rb')
    rdoc.rdoc_files.include('lib/seek/rdf/rdf_generation.rb')
  }
end
