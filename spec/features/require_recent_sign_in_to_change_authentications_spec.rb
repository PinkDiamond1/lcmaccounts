require 'rails_helper'

feature 'Require recent log in to change authentications', js: true do

  scenario 'adding Facebook' do
    user = create_user 'user'

    log_in('user', 'password')

    expect_profile_page

    Timecop.freeze(Time.now + RequireRecentSignin::REAUTHENTICATE_AFTER) do
      expect(page).not_to have_content('Facebook')
      screenshot!
      click_link 'Enable other sign in options'
      wait_for_animations
      screenshot!
      expect(page).to have_no_content('Enable other sign in options')
      expect(page).to have_content('Other sign in options')
      expect(page).to have_content('Facebook')

      with_omniauth_test_mode(identity_user: user) do
        find('.authentication[data-provider="facebook"] .add').click
        wait_for_ajax
        expect(page).to have_content(t :"sessions.reauthenticate.page_heading")
        screenshot!
        complete_login_password_screen('password')
        expect_profile_page
        expect(page).to have_content('Facebook')
        screenshot!
      end
    end
  end

  scenario 'changing the password' do
    with_forgery_protection do
      create_user 'user'

      log_in('user', 'password')

      expect(page).to have_no_missing_translations

      Timecop.freeze(Time.now + RequireRecentSignin::REAUTHENTICATE_AFTER) do
        visit '/profile'
        expect_profile_page

        screenshot!
        find('.authentication[data-provider="identity"] .edit').click

        expect(page).to have_content(t :"sessions.reauthenticate.page_heading")
        complete_login_password_screen('password')
        screenshot!

        complete_reset_password_screen
        screenshot!
        complete_reset_password_success_screen

        screenshot!
        expect_profile_page

        find('.authentication[data-provider="identity"] .edit').click

        # Don't have to reauthenticate since just did
        expect(page).not_to have_content(t :"sessions.reauthenticate.page_heading")

        complete_reset_password_screen
        complete_reset_password_success_screen
      end
    end
  end

  scenario 'removing an authentication' do
    with_forgery_protection do
      user = create_user 'user'
      FactoryGirl.create :authentication, user: user, provider: 'twitter'

      log_in('user', 'password')

      expect(page).to have_no_missing_translations

      Timecop.freeze(Time.now + RequireRecentSignin::REAUTHENTICATE_AFTER) do
        visit '/profile'
        expect_profile_page
        expect(page).to have_content('Twitter')
        screenshot!

        find('.authentication[data-provider="twitter"] .delete').click
        screenshot!
        click_button 'OK'
        expect(page).to have_content(t :"sessions.reauthenticate.page_heading")
        screenshot!

        complete_login_password_screen('password')
        expect_profile_page
        screenshot!

        find('.authentication[data-provider="twitter"] .delete').click
        screenshot!
        click_button 'OK'
        expect(page).not_to have_content('Twitter')
      end
    end
  end

end
