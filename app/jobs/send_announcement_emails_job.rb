class SendAnnouncementEmailsJob < Struct.new(:site_announcement_id, :from_notifiee_id)
  DEFAULT_PRIORITY=3
  BATCHSIZE=50

  def perform
    site_announcement = SiteAnnouncement.find_by_id(site_announcement_id)
    if site_announcement
      send_announcement_emails site_announcement, from_notifiee_id
    end  
    from_new_notifiee_id = from_notifiee_id + BATCHSIZE + 1
    if NotifieeInfo.last.id >= from_new_notifiee_id
       SendAnnouncementEmailsJob.create_job(site_announcement_id,from_new_notifiee_id)
    end
  end

  def self.exists? site_announcement_id, from_notifiee_id
    Delayed::Job.find(:first, :conditions => ['handler = ? AND locked_at IS ? AND failed_at IS ?', SendAnnouncementEmailsJob.new(site_announcement_id, from_notifiee_id).to_yaml, nil, nil]) != nil
  end

  def self.create_job site_announcement_id, from_notifiee_id, t=30.seconds.from_now, priority=DEFAULT_PRIORITY
    Delayed::Job.enqueue(SendAnnouncementEmailsJob.new(site_announcement_id, from_notifiee_id), priority, t) unless exists?(site_announcement_id, from_notifiee_id)
  end

  def send_announcement_emails site_announcement, from_notifiee_id
    if Seek::Config.email_enabled
      NotifieeInfo.find(:all, :conditions=>["id IN (?) AND receive_notifications=?", (from_notifiee_id .. (from_notifiee_id + BATCHSIZE)), true]).each do |notifiee_info|
        begin
          Mailer.deliver_announcement_notification(site_announcement, notifiee_info, Seek::Config.site_base_host.gsub(/https?:\/\//,''))
        rescue Exception=>e
          if defined? RAILS_DEFAULT_LOGGER
            RAILS_DEFAULT_LOGGER.error "There was a problem sending an announcement email to #{notifiee_info.notifiee.email} - #{e.message}."
          end
        end
      end
    end
  end
end