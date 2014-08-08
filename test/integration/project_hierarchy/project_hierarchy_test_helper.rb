module ProjectHierarchyTestHelper

  def setup
        initialize_hierarchical_projects
  end

  def reload_extended_models
    [Project, Person, Assay, Study].each do |klass|
      force_reload_model klass.name
    end

    force_reload_model ProjectCompat.name, "#{Rails.root}/lib/project_compat.rb"

    Seek.send(:remove_const, "AdminDefinedRoles")
    load "#{Rails.root}/lib/seek/admin_defined_roles.rb"
  end
  def force_reload_model model_name, path=nil
     model_path = path.nil? ?  "#{Rails.root}/app/models/#{model_name.underscore}.rb" : path

     Object.send(:remove_const, model_name)
     load model_path
  end


  def login_as_test_user
    User.current_user = Factory(:user, :login => 'test')
    #test actions in controller with User.current_user not nil
    post '/session', :login => 'test', :password => 'blah'
  end

  def initialize_hierarchical_projects
    @proj = Factory(:project, :title => "parent project")
    @proj_child1 = Factory :project, :title => "child1 project", :parent_id => @proj.id
    @proj_child2 = Factory :project, :title => "child2 project", :parent_id => @proj.id
    @subscribables_in_proj = [Factory(:subscribable, :projects => [Factory(:project), @proj]),
                              Factory(:subscribable, :projects => [@proj, Factory(:project), Factory(:project)]),
                              Factory(:subscribable, :projects => [@proj])]
  end

  def new_person_with_hierarchical_projects
    person = Factory(:brand_new_person)
    #add 2 work_groups directly
    person.work_groups.create :project => @proj_child1, :institution => Factory(:institution)
    person.work_groups.create :project => @proj_child2, :institution => Factory(:institution)
    disable_authorization_checks do
      #save person in order to save built project subscriptions
      person.save!
    end
    person.reload

    person
  end

  #perform delayed jobs when they are created for easy test
  def sync_delayed_jobs  delayed_job_classes=[]
     Delayed::Job.class_eval %Q{
       def self.enqueue(*args)
         obj = args.shift
         obj.perform if #{delayed_job_classes}.detect{|job_class| obj.is_a? job_class}
       end
     }
    end

  def current_person
    User.current_user.person
  end


end