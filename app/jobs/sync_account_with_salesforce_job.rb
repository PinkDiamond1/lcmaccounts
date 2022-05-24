class SyncAccountWithSalesforceJob < ApplicationJob
  queue_as :salesforce_accounts_sync

  def perform(user_id)
    # this is controlled in secrets.yml (or param store for non-dev/test envs)
    return unless Rails.application.secrets[:salesforce][:sync_accounts_enabled]

    user = User.find(user_id)

    if user.salesforce_ox_account_id
      sf_ox_account =
        OpenStax::Salesforce::Remote::OpenStaxAccount.find(user.salesforce_ox_account_id)
      sf_ox_account.account_role = user.role.titleize
      sf_ox_account.faculty_status = user.faculty_status
      sf_ox_account.salesforce_contact_id = user.salesforce_contact_id
      # to handle not trying to update a lead id that has been converted
      sf_ox_account.salesforce_lead_id = user.salesforce_lead_id if sf_ox_account.salesforce_lead_id.blank?
    else
      sf_ox_account = OpenStax::Salesforce::Remote::OpenStaxAccount.new(
        account_id:            user_id,
        account_uuid:          user.uuid.to_s,
        account_role:          user.role.titleize,
        faculty_status:        user.faculty_status,
        salesforce_contact_id: user.salesforce_contact_id,
        salesforce_lead_id:    user.salesforce_lead_id,
        signup_date:           user.created_at.strftime("%Y-%m-%dT%H:%M:%S%z"),
        account_environment:   Rails.application.secrets.environment_name
      )
    end

    sf_ox_account.save!
    user.salesforce_ox_account_id = sf_ox_account.id

    begin
      user.save!
      SecurityLog.create!(
        user:       user,
        event_type: :account_created_or_synced_with_salesforce,
        event_data: { sf_ox_account_id: sf_ox_account.id }
      )
      return true
    rescue => e
      Sentry.capture_exception(e)
      return
    end
  end
end
