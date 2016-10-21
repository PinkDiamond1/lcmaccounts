class UpdateUserSalesforceInfo
  USER_BLOCK_SIZE = 1000

  def initialize
    @errors = []
  end

  def self.call
    new.call
  end

  def call
    contacts_by_email = {}
    contacts_by_id = {}

    contacts.each do |contact|
      contacts_by_email[contact.email] = contact
      contacts_by_id[contact.id] = contact
    end

    # Go through all users that have already have a Salesforce ID and make sure
    # their SF information is stil the same.

    User.where("salesforce_contact_id IS NOT NULL")
        .find_each do |user|

      begin
        contact = contacts_by_id[user.salesforce_contact_id]
        cache_contact_data_in_user(contact, user)
        user.save! if user.changed?
      rescue StandardError => ee
        error!(exception: ee, user: user)
      end
    end

    # Go through all users that don't yet have a Salesforce ID and populate their
    # salesforce info when they have verified emails that match SF data.

    sf_emails = contacts_by_email.keys

    User.eager_load(:contact_infos)
        .where(salesforce_contact_id: nil)
        .where(contact_infos: { value: sf_emails, verified: true })
        .find_each do |user|

      begin
        # The query above really should be limiting us to only verified email addresses
        # but in case there is some odd thing where a User has multiple addresses some
        # of which are verified and some are not, and in case `user.contact_infos` gets
        # those, add this extra `select(&:verified?)` call

        contacts = user.contact_infos.select(&:verified?).map{|ci| contacts_by_email[ci.value]}

        next if contacts.size == 0

        if contacts.size > 1
          error!(message: "More than one SF contact (#{contacts.map(&:id).join(', ')}) " \
                          "for user #{user.id}")
        else
          cache_contact_data_in_user(contacts.first, user)
          user.save!
        end
      rescue StandardError => ee
        error!(exception: ee, user: user)
      end
    end

    notify_errors
  end

  def cache_contact_data_in_user(contact, user)
    if contact.nil?
      user.salesforce_contact_id = nil
      user.faculty_status = User::DEFAULT_FACULTY_STATUS
    else
      user.salesforce_contact_id = contact.id

      user.faculty_status = case contact.faculty_verified
      when "Confirmed"
        :confirmed_faculty
      when "Pending"
        :pending_faculty
      when /Rejected/
        :rejected_faculty
      when nil
        :no_faculty_info
      else
        raise "Unknown faculty_verified field: '#{contact.faculty_verified}'' on contact #{contact.id}"
      end
    end
  end

  def contacts
    # The query below is not particularly fast, takes around a minute.  We could
    # try to do something fancier, like only query contacts modified in the last day
    # or keep track of when the SF data was last updated and use those timestamps
    # to limit what data we pull from Salesforce (could have a global field in redis
    # or could copy SF contact "LastModifiedAt" to a "sf_refreshed_at" field on each
    # User record).
    #
    # Here's one example query as a starting point:
    #   Salesforce::Contact.order("LastModifiedDate").where("LastModifiedDate >= #{1.day.ago.utc.iso8601}")

    # TODO DEAL WITH EMAIL_ALT!! Not guaranteed to be unique unfortunately

    @contacts ||= Salesforce::Contact.select(:id, :email, :faculty_verified).to_a
  end

  def error!(exception: nil, message: nil, user: nil)
    error = {}

    error[:message] = message || exception.try(:message)
    error[:exception] = {
      class: exception.class.name,
      message: exception.message,
      first_backtrace_line: exception.backtrace.try(:first)
    } if exception.present?
    error[:user] = user.try(:id)

    @errors.push(error)
  end

  def notify_errors
    return if @errors.empty?
    Rails.logger.warn("UpdateUserSalesforceInfo errors: " + @errors.inspect)
    DevMailer.pp(object: @errors,
                 subject: "UpdateUserSalesforceInfo errors",
                 to: SECRET_SETTINGS[:mail_recipients][:salesforce]).deliver
  end

end
