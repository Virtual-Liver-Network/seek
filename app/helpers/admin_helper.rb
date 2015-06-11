module AdminHelper

  #true for tags with a name longer than 50chars or containing a semi-colon, comma, forward slash, colon or pipe character
  def dubious_tag?(tag)
    tag.text.length>50 || [";",",",":","/","|"].detect{|c| tag.text.include?(c)}
  end
  
  def admin_mail_to_links   
    result=""
    admins=Person.admins
    admins.each do |person|
      result << mail_to(h(person.email),h(person.name))
      result << ", " unless admins.last==person
    end
    return result.html_safe
  end
  
  #takes the terms and scores received from SearchStats, and generates a string
  def search_terms_summary terms_and_scores    
    return "<span class='none_text'>No search queries during this period</span>".html_safe if terms_and_scores.empty?
    words=terms_and_scores.collect{|ts| "#{h(ts[0])}(#{ts[1]})" }
    words.join(", ").html_safe
  end

  def delayed_job_status
    status = ""
    begin
      pids = [0,1].collect do |n|
        Daemons::PidFile.new("#{Rails.root}/tmp/pids","delayed_job.#{n.to_s}")
      end
      pids.each do |pid|
        if pid.running?
          status << "Running [Process ID: #{pid.pid}]"
        else
          status << "<span class='error_text'>Not running</span>"
        end
        status << "&nbsp;:&nbsp;" unless pid == pids.last
      end

    rescue Exception=>e
      status = "<span class='error_text'>Unable to determine current status - #{e.message}</span>"
    end
    status.html_safe
  end

  def action_buttons user_or_person, action
    case action
      when "activate"
        if user_or_person.is_a?(User) && user_or_person.person
          admin_activate_user_button = content_tag(:li, image_tag_for_key('activate', activate_path(:activation_code => user_or_person.activation_code), "user activation", {}, "Activate now"))
          resend_activation_email_button = content_tag(:li, image_tag_for_key('message', resend_activation_email_user_path(user_or_person), "Resend activation email", {:method => :post}, "Resend activation email"))
          buttons =  admin_activate_user_button + resend_activation_email_button
        end
      when "delete"
        buttons = content_tag(:li, image_tag_for_key('destroy', user_or_person , "delete", {:method => :delete, :confirm => "Are you sure you wish to delete this #{user_or_person.class.name}?"}, "Delete"))
      else
        nil
    end
    content_tag(:ul, buttons, :class => "sectionIcons")
  end

  # provides a url to the header image to be served from public/assets/logos/ - copying the image from filestore across if necessary
  def public_header_image_url filename
    image_folder = Seek::Config.rebranding_filestore_path
    unless File.exist?(image_folder)
      FileUtils.mkdir_p(image_folder)
    end
    image_file_path = File.join(image_folder, filename)

    public_logos_dir = File.join(Rails.configuration.assets.prefix, 'logos')
    public_logo_path = File.join(Rails.root, 'public', public_logos_dir)
    unless File.exist?(public_logo_path)
      FileUtils.mkdir_p public_logo_path
    end

    public_file_path = File.join(public_logo_path, filename)
    if !File.exist?(public_file_path) && File.exist?(image_file_path)
      FileUtils.copy(image_file_path, public_logo_path)
    end

    File.join(public_logos_dir, filename)
  end
   def admin_text_setting(name, value, title, description = nil, options = {})
    admin_setting_block(title, description) do
      text_field_tag(name, value, options.merge!(:class => 'form-control'))
    end
  end

  def admin_textarea_setting(name, value, title, description = nil, options = {})
    rows = options[:rows].nil? ? 5 : options[:rows]
    admin_setting_block(title, description) do
      text_area_tag(name, value, options.merge!(:rows => rows, :class => 'form-control'))
    end
  end

  def admin_file_setting(name, title, description = nil, options = {})
    admin_setting_block(title, description) do
      file_field_tag(name, options)
    end
  end

  def admin_password_setting(name, value, title, description = nil, options = {})
    admin_setting_block(title, description) do
      password_field_tag(name, value, options.merge!(:autocomplete => 'off', :class => 'form-control'))
    end
  end

  def admin_checkbox_setting(name, value, checked, title, description = nil, options = {})
    content_tag(:div, :class => 'checkbox') do
      content_tag(:label, :class => 'admin-checkbox') do
        check_box_tag(name, value, checked, options) + title.html_safe
      end +
          (description ? content_tag(:p, description.html_safe, :class => 'help-block') : ''.html_safe)
    end
  end

  private

  def admin_setting_block(title, description)
    content_tag(:div, :class => 'form-group') do
      content_tag(:label, title) +
          (description ? content_tag(:p, description.html_safe, :class => 'help-block') : ''.html_safe) +
          yield
    end
  end


end
