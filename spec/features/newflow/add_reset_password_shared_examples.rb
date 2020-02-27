RSpec.shared_examples "add_reset_password_shared_examples" do |parameter|
  let(:type) { parameter }

  before(:each) do
    turn_on_feature_flag

    @user = create_user 'user'
    @login_token = generate_login_token_for 'user'

    if :add == type
      identity_authentication = @user.authentications.first
      FactoryBot.create :authentication, user: @user, provider: 'facebook'
      @user.identity.destroy!
      identity_authentication.destroy!
    end
  end

  scenario 'using a link without a code' do
    visit start_path(type: type)
    screenshot!
    expect(page).to have_no_missing_translations
    expect(page).to have_content(t :"identities.set.there_was_a_problem_with_password_link")
    expect(page).to have_current_path start_path(type: type)
  end

  scenario 'using a link with an invalid code' do
    visit start_path(type: type, token: '1234')
    screenshot!
    expect(page).to have_no_missing_translations
    expect(page).to have_content(t :"identities.set.there_was_a_problem_with_password_link")
    expect_page(type: type, token: '1234')
  end

  xscenario 'using a link with an expired code' do
    @login_token = generate_expired_login_token_for 'user'
    visit start_path(type: type, token: @login_token)
    screenshot!
    expect(page).to have_no_missing_translations
    expect(page).to have_content(t :"identities.set.expired_password_link")
    expect_page(type: type)
  end

  xscenario 'using a link with a valid code' do
    visit start_path(type: type, token: @login_token)
    expect(page).to have_no_missing_translations
    expect(page.first('#set_password_password_confirmation')["placeholder"]).to eq t :"identities.set.confirm_password"
    expect_page(type: type)
  end

  xscenario 'with a blank password' do
    visit start_path(type: type, token: @login_token)
    expect_page(type: type)
    click_button (t :"identities.#{type}.submit")
    expect(page).to have_content(error_msg Identity, :password, :blank)
    screenshot!
  end

  xscenario 'password is too short' do
    visit start_path(type: type, token: @login_token)
    expect(page).to have_no_missing_translations
    expect_page(type: type)
    fill_in (t :"identities.set.password"), with: 'pass'
    fill_in (t :"identities.set.confirm_password"), with: 'pass'
    click_button (t :"identities.#{type}.submit")
    expect(page).to have_content(error_msg Identity, :password, :too_short, count: 8)
    screenshot!
  end

  scenario 'successful' do
    visit start_path(type: type, token: @login_token)
    expect(page).to have_no_missing_translations
    fill_in(t(:"login_signup_form.password_label"), with: '1234abcd')
    find('#login-signup-form').click # to hide the password tooltip
    wait_for_animations
    find('[type=submit]').click
    expect(page).to have_content(t(:"identities.#{type}_success.message"))

    expect_newflow_profile_page

    click_link (t :"users.edit.sign_out")
    visit '/'
    expect(page).to have_current_path newflow_login_path

    # try logging in with the old password
    newflow_log_in_user('user', 'password')
    expect(page).to have_content(t(:"login_signup_form.incorrect_password"))

    # try logging in with the new password
    newflow_log_in_user('user', '1234abcd')

    expect_newflow_profile_page
    expect(page).to have_no_missing_translations
    expect(page).to have_content(@user.full_name)
  end

  def expect_reset_password_page(code = @login_token)
    expect(page).to have_current_path forgot_password_form_path(token: code)
    expect(page).to have_no_missing_translations
  end

  def expect_page(type:, token: @login_token)
    expect(page).to have_current_path start_path(type: type, token: token)
    expect(page).to have_no_missing_translations
  end

  def start_path(type:, token: nil)
    case type
    when :reset
      token.present? ? change_password_form_path(token: token) : change_password_form_path
    when :add
      token.present? ? create_password_form_path(token: token) : create_password_form_path
    end
  end
end
