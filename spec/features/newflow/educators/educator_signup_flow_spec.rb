require 'rails_helper'

module Newflow

  feature 'Educator signup flow', js: true do

    background { load 'db/seeds.rb' }
    before(:each) { turn_on_educator_feature_flag }

    let(:first_name) { "Elon#{Faker::Alphanumeric.alphanumeric(number: 20)}" }
    let(:last_name) { "Musk#{Faker::Alphanumeric.alphanumeric(number: 20)}" }
    let(:phone_number) { Faker::PhoneNumber.phone_number }
    let(:email_value) { "#{Faker::Alphanumeric.alphanumeric(number: 20)}@rice.edu" }
    let(:password) { Faker::Internet.password(min_length: 8) }
    let(:sheerid_iframe_page_title) { 'Verify your instructor status' }
    let(:iframe_submit_button_text) { 'Verify my instructor status' }
    let(:external_app_url) { capybara_url(external_app_for_specs_path) }
    let(:return_param) { { r: external_app_for_specs_path } }

    context 'happy path' do
      before(:each) do
        expect_any_instance_of(EducatorSignup::CreateSalesforceLead).to receive(:exec)
      end

      context 'when entering PIN code to verify email address' do
        it 'all works' do
          visit(login_path(return_param))
          click_on(I18n.t(:"login_signup_form.sign_up"))
          click_on(I18n.t(:"login_signup_form.educator"))

          fill_in 'signup_first_name',	with: first_name
          fill_in 'signup_last_name',	with: last_name
          fill_in 'signup_phone_number', with: phone_number
          fill_in 'signup_email',	with: email_value
          fill_in 'signup_password',	with: password
          submit_signup_form
          screenshot!

          # sends an email address confirmation email
          expect(page.current_path).to eq(educator_email_verification_form_path)
          open_email(email_value)
          capture_email!(address: email_value)
          expect(current_email).to be_truthy

          # ... with a link
          verify_email_url = get_path_from_absolute_link(current_email, 'a')
          visit(verify_email_url)
          # ... which sends you to the SheerID form
          expect(page.current_path).to eq(educator_sheerid_form_path)

          expect_sheerid_iframe

          find('#signup_educator_specific_role_other').click
          fill_in('Other (please specify)', with: 'President')
          click_on('Continue')
          expect(page.current_path).to eq(signup_done_path)
          click_on('Finish')
          expect(page.current_url).to eq(external_app_url)

          # # can exit and go back to the app they came from
          # find('#exit-icon a').click
          # expect(page.current_path).to eq('/external_app_for_specs')
          # screenshot!
        end
      end

      context 'when clicking on link sent in an email to verify email address' do
        let(:correct_pin) { EmailAddress.last.confirmation_pin }

        it 'all works' do
          visit(login_path(return_param))
          click_on(I18n.t(:"login_signup_form.sign_up"))
          expect(page.current_path).to eq(newflow_signup_path)
          click_on(I18n.t(:"login_signup_form.educator"))

          fill_in 'signup_first_name',	with: first_name
          fill_in 'signup_last_name',	with: last_name
          fill_in 'signup_phone_number', with: phone_number
          fill_in 'signup_email',	with: email_value
          fill_in 'signup_password',	with: password
          submit_signup_form
          screenshot!

          # sends an email address confirmation email
          expect(page.current_path).to eq(educator_email_verification_form_path)
          open_email(email_value)
          capture_email!(address: email_value)
          expect(current_email).to be_truthy

          # ... with the correct PIN
          fill_in 'confirm_pin', with: correct_pin
          find('[type=submit]').click
          # ... sends you to the SheerID form
          expect(page.current_path).to eq(educator_sheerid_form_path)

          expect_sheerid_iframe

          find('#signup_educator_specific_role_other').click
          fill_in('Other (please specify)', with: 'President')
          click_on('Continue')
          expect(page.current_path).to eq(signup_done_path)
          click_on('Finish')
          expect(page.current_url).to eq(external_app_url)

          # # can exit and go back to the app they came from
          # find('#exit-icon a').click
          # expect(page.current_path).to eq('/external_app_for_specs')
          # screenshot!
        end
      end
    end

    context 'when educator stops signup flow, logs out, after completing step 2' do
      it 'redirects them to continue signup flow (step 3) after logging in'
    end

    context 'when educator stops signup flow, logs out, after completing step 3' do
      it 'redirects them to continue signup flow (step 4) after logging in'
    end

    context 'when legacy educator wants to request faculty verification' do
      before(:each) { visit(login_path) }

      let(:educator) { FactoryBot.create(:user, role: User::INSTRUCTOR_ROLE) }

      context 'with faculty status as no_faculty_info' do
        it 'sends them to step 3 — SheerID iframe'
      end

      context 'with faculty status as rejected' do
        it 'sends them to step 4 — Educator Profile Form'
      end
    end

    context 'when educators have been rejected by SheerID one or more times' do
      context 'and have been in the pending faculty status step for more than 4 days' do
        it 'will send them through the CS verification process (modified step 4)'
      end
    end

    context 'when educator uses the browser\'s built-in back-arrow' do
      context 'after completing step 1' do
        it 'sends them back to the next, correct, step'
      end

      context 'after completing step 2' do
        it 'sends them back to the next, correct, step'
      end

      context 'after completing step 3' do
        it 'sends them back to the next, correct, step'
      end

      context 'after completing step 4' do
        it 'sends them back to the next, correct, step'
      end
    end

  end

end
