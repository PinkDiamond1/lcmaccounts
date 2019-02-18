require 'rails_helper'

describe EmailAddress, type: :model do
  # format validation specs in `email_address_validations_spec.rb`
  # email address provider validation specs in `domain_mx_validator_spec.rb`

  INVALID_PROVIDER = "#{SecureRandom.hex(3)}.#{SecureRandom.hex(3)}"

  let(:strategy) { double('validator') }

  before(:each) do
    EmailDomainMxValidator.strategy = strategy
  end

  describe 'when email provider is whitelisted' do
    it 'does not call the strategy' do
      whitelisted_provider = EmailAddress::WHITELIST.sample
      expect(strategy).to receive(:check).exactly(0).times

      email = EmailAddress.new
      email.user = FactoryGirl.create(:user)
      email.value = "WHATEVER@#{whitelisted_provider}"
      email.valid?
    end
  end

  describe 'when not whitelisted nor blacklisted' do
    it 'delegates responsibility of email provider validation' do
      expect(strategy).to receive(:check).with(INVALID_PROVIDER)

      email = EmailAddress.new
      email.user = FactoryGirl.create(:user)
      email.value = "WHATEVER@#{INVALID_PROVIDER}"
      email.valid?
    end
  end

  describe 'when not valid email provider' do
    before do
      expect(strategy).to receive(:check).with(INVALID_PROVIDER).and_return(false)
    end

    it 'adds an error missing_mx_records' do
      email = EmailAddress.new
      email.user = FactoryGirl.create(:user)
      email.value = "WHATEVER@#{INVALID_PROVIDER}"
      email.valid?
      expect(email).to have_error(:value, :missing_mx_records)
    end

    it 'blacklists domain in the database' do
      email = EmailAddress.new
      email.user = FactoryGirl.create(:user)
      email.value = "WHATEVER@#{INVALID_PROVIDER}"

      expect{
        email.valid?
      }.to change {
        EmailDomain.where(value: INVALID_PROVIDER, has_mx: false).count
      }
    end
  end

  describe 'when valid email provider' do
    let(:provider) { 'anyValidEmailProvider123.com' }

    before(:each) do
      expect(strategy).to receive(:check).with(provider).and_return(true)
    end

    it 'whitelists email provider in the database' do
      email = EmailAddress.new
      email.user = FactoryGirl.create(:user)
      email.value = "WHATEVER@#{provider}"

      expect{
        email.valid?
      }.to change {
        EmailDomain.where(value: provider, has_mx: true).count
      }
    end
  end
end
