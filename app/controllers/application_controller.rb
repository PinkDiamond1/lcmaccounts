class ApplicationController < ActionController::Base

  include ApplicationHelper

  layout 'application'

  before_action :authenticate_user!, only: :profile
  before_action :ensure_complete_educator_signup, only: :profile

  def disable_fine_print
    request.options? ||
    contracts_not_required ||
    current_user.is_anonymous?
  end

  def check_if_admin
    return true if !Rails.env.production?
    is_admin?
  end

  def return_url_specified_and_allowed?
    # This returns true if `save_redirect` actually saved the URL
    params[:r] && params[:r] == stored_url
  end

  include Lev::HandleWith

  respond_to :html

  protected

  def restart_signup_if_missing_verified_user
    redirect_to signup_path unless unverified_user.present?
  end

  def allow_iframe_access
    @iframe_parent = params[:parent]

    if @iframe_parent.blank?
      response.headers.except! 'X-Frame-Options'
      return true
    end

    if Host.trusted? @iframe_parent
      response.headers.except! 'X-Frame-Options'
    else
      raise SecurityTransgression.new("#{@iframe_parent} is not allowed to iframe content")
    end
    true
  end
end
