require 'rails_helper'

describe ActivateUser, type: :routine  do
  context 'when success' do
    before do
      disable_sfdc_client
      allow(Settings::Salesforce).to receive(:push_salesforce_lead_enabled).and_return(true)
    end

    let(:user) do
      FactoryBot.create(:user, state: 'unverified', role: 'student', receive_newsletter: true)
    end

    it 'does NOT sign up user for the newsletter when NOT checked' do
      user.update!(receive_newsletter: false)
      expect_any_instance_of(CreateSalesforceLead).not_to receive(:exec)
      described_class.call(user)
    end
  end
end
