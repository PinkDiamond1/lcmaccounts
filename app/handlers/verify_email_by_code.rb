# Marks an `EmailAddress` as `verified` if it matches the passed-in `EmailAddress`'s pin
# and then marks the owner of the email address as 'activated'.
class VerifyEmailByCode
  lev_handler
  uses_routine ConfirmByCode,
               translations: { outputs: { type: :verbatim },
                               inputs: { type: :verbatim } }
  uses_routine ActivateUser

  def authorized?
    true
  end

  def handle
    run(ConfirmByCode, params[:code])

    fatal_error(code: :no_contact_info_for_code, message: (I18n.t :"routines.confirm_by_code.unable_to_verify_address")) if code.nil?

    contact_info = ContactInfo.find_by(confirmation_code: params[:code])

    fatal_error(code: :no_contact_info_for_code, message: (I18n.t :"routines.confirm_by_code.unable_to_verify_address")) if contact_info.nil?

    run(ConfirmContactInfo, contact_info)

    # Now that this contact info confirmed by code, re-allow pin confirmation in the future
    ConfirmByPin.sequential_failure_for(contact_info).reset!

    outputs[:contact_info] = contact_info

    user = outputs.contact_info.user

    run(ActivateUser, user)

    outputs.user = user
    outputs.contact_info = outputs.contact_info
  end
end
