
class Study < ActiveRecord::Base

  include Seek::Rdf::RdfGeneration
  include Seek::ProjectHierarchies::ItemsProjectsExtension if Seek::Config.project_hierarchy_enabled

  #FIXME: needs to be declared before acts_as_isa, else ProjectCompat module gets pulled in
  def projects
    investigation.try(:projects) || []
  end

  acts_as_isa

  attr_accessor :new_link_from_assay

  belongs_to :investigation
  has_many :assays
  belongs_to :person_responsible, :class_name => "Person"
  validates :investigation, :presence => true

  searchable(:auto_index => false) do
    text :experimentalists
    text :person_responsible do
      person_responsible.try(:name)
    end
  end if Seek::Config.solr_enabled

  #FIXME: see comment in Assay about reversing these
  ["data_file","sop","model","publication"].each do |type|
    eval <<-END_EVAL
      def #{type}_masters
        assays.collect{|a| a.send(:#{type}_masters)}.flatten.uniq
      end

      def #{type}s
        assays.collect{|a| a.send(:#{type}s)}.flatten.uniq
      end

      #related items hash will use data_file_masters instead of data_files, etc. (sops, models)
      def related_#{type.pluralize}
        #{type}_masters
      end
    END_EVAL
  end

  def project_ids
    projects.map(&:id)
  end

  def state_allows_delete? *args
    assays.empty? && super
  end

  def clone_with_associations
    new_object= self.dup
    new_object.policy = self.policy.deep_copy

    return new_object
  end

end
