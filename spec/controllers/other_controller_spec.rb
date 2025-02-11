require 'rails_helper'

RSpec.describe OtherController, type: :controller do
  describe 'GET #profile' do
    context 'when logged in' do
      before do
        user.update!(role: User::INSTRUCTOR_ROLE)
        mock_current_user(user)
      end

      let(:user) { create_user('user@openstax.org') }

      context 'when profile is complete' do
        before do
          user.update!(is_profile_complete: true)
        end

          it 'renders 200 OK status' do
          get(:profile)
          expect(response.status).to eq(200)
        end

        it 'renders profile' do
          get(:profile)
          expect(response).to render_template(:profile)
        end
      end

      context 'when profile is not complete' do
        before { user.update!(is_profile_complete: false) }

        it 'redirects to step 4 — complete profile form' do
          get(:profile)
          expect(response).to redirect_to(educator_profile_form_path)
        end
      end
    end

    context 'while not logged in' do
      it 'redirects to login form' do
        get(:profile)
        expect(response).to redirect_to login_path
      end
    end
  end

  describe "GET #exit_accounts" do
    let(:host) { Rails.application.secrets.trusted_hosts.first }
    let(:target_url) { Faker::Internet.url }

    context 'when Referer is present' do
      before do
        request.headers.merge!({ Referer: subject })
      end

      context 'when Referer includes `r` param' do
        subject do
          "#{host}?r=#{target_url}"
        end

        context 'when `r` is trusted' do
          before do
            allow(Host).to receive(:trusted?).with(target_url).once.and_return(true)
          end

          it 'redirects to `r`' do
            get(:exit_accounts)
            expect(response).to redirect_to(target_url)
          end
        end

        context 'when `r` is not trusted' do
          before do
            allow(Host).to receive(:trusted?).with(target_url).once.and_return(false)
          end

          it 'is forbidden' do
            get(:exit_accounts)
            expect(response).to have_http_status(:forbidden)
          end
        end
      end
    end

    context 'when Referer is nil' do
      it 'redirects back' do
        expect_any_instance_of(described_class).to receive(:redirect_back).and_call_original
        get(:exit_accounts)
        expect(response).to redirect_to(root_url)
      end
    end

    context 'when the stored url includes `redirect_uri` param' do
      before do
        allow_any_instance_of(described_class).to receive(:stored_url).and_return(redirect_uri)
      end

      let(:redirect_uri) do
        "#{host}?redirect_uri=#{target_url}"
      end

      it 'redirects to `redirect_uri`' do
        get(:exit_accounts)
        expect(response).to redirect_to(target_url)
      end
    end
  end
end
