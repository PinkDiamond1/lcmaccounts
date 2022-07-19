class SessionsController < ApplicationController
  include LoginSignupHelper

  skip_before_action :authenticate_user!, only: [:login_form, :login_post]

  before_action :cache_client_app, only: :login_form
  before_action :cache_alternate_signup_url, only: :login_form
  before_action :check_if_password_expired
  before_action :maybe_skip_to_sign_up
  before_action :store_authorization_url_as_fallback
  #before_action :redirect_back, if: -> { signed_in? }, only: :login_form

  def login_form
    redirect_back(fallback_location: profile_path) and return if signed_in?

    clear_signup_state
  end

  def login_post
    handle_with(
      LogInUser,
      success: lambda {
        user = @handler_result.outputs.user

        if user.unverified?
          save_unverified_user(user.id)
          redirect_to verify_email_by_pin_form_path and return
        end

        sign_in!(user, security_log_data: {'email': @handler_result.outputs.email})

        if current_user.student? || current_user.is_profile_complete?
          redirect_back
        else
            # moved from educator_signup_flow_decorator, slated for refactoring because this is confusing
            if @current_step == 'login' && !current_user.is_profile_complete && current_user.sheerid_verification_id.blank?
              sheerid_form_path
            elsif @current_step == 'login' && (current_user.sheerid_verification_id.present? || current_user.is_sheerid_unviable?)
              profile_form_path
            elsif @current_step == 'educator_sheerid_form'
              if current_user.confirmed_faculty? || current_user.rejected_faculty? || current_user.sheerid_verification_id.present?
                #TODO: what is this?
              end
            elsif @current_step == 'educator_signup_form' && !current_user.is_anonymous?
              verify_email_by_pin_form_path
            elsif @current_step == 'educator_email_verification_form' && @user.activated?
              if !current_user.student? && current_user.activated? && current_user.pending_faculty && current_user.sheerid_verification_id.blank?
                sheerid_form_path
              elsif current_user.activated?
                profile_form_path
              end
            end
          end
      },
      failure: lambda {
        email = @handler_result.outputs.email
        save_login_failed_email(email)

        code = @handler_result.errors.first.code
        case code
        when :cannot_find_user, :multiple_users, :incorrect_password, :too_many_login_attempts
          user = @handler_result.outputs.user
          security_log(:sign_in_failed, { reason: code, email: email })
        end

        render :login_form
      }
    )
  end

  def reauthenticate_form; end

  def reauthenticate_post; end # TODO: post to login_post?

  def logout
    sign_out!
    redirect_back
  end

  def exit_accounts
    if (redirect_param = extract_params(request.referrer)[:r])
      if Host.trusted?(redirect_param)
        redirect_to(redirect_param)
      else
        raise Lev::SecurityTransgression
      end
    elsif !signed_in? && (redirect_uri = extract_params(stored_url)[:redirect_uri])
      redirect_to(redirect_uri)
    else
      redirect_back
    end
  end

  protected

  # Save (in the session) or clear the URL that the "Sign up" button in the FE points to.
  # -- Tutor uses this to send students who want to sign up, back to Tutor which
  # has a message for students just letting them know how to sign up (they must receive an email invitation).
  def cache_alternate_signup_url
    set_alternate_signup_url(params[:signup_at])
  end

  def check_if_password_expired
    return true if request.format != :html || request.options?

    identity = current_user.identity
    return unless identity.try(:password_expired?)

    flash[:alert] = I18n.t(:"controllers.identities.password_expired")
    redirect_to(password_reset_path)
  end

  def store_authorization_url_as_fallback
    # In case we need to redirect_back, but don't have something to redirect back
    # to (e.g. no authorization url or referrer), form and store as the fallback
    # an authorization URL.  Handles the case where the user got sent straight to
    # the login page.  Only works if we have know the client app.

    client_app = get_client_app
    return if client_app.nil?

    redirect_uri      = client_app.redirect_uri.lines.first.chomp
    authorization_url = oauth_authorization_url(client_id: client_app.uid,
                                                redirect_uri: redirect_uri,
                                                response_type: 'code')

    store_fallback(url: authorization_url) unless authorization_url.nil?
  end
end
