# frozen_string_literal: true

RSpec.shared_examples 'creates a user with ArkoseLabs risk band on signup request' do
  let(:arkose_labs_params) { { arkose_labs_token: 'arkose-labs-token' } }
  let(:params) { { user: user_attrs }.merge(arkose_labs_params) }

  let(:successful_service_response) do
    json = Gitlab::Json.parse(
      File.read(Rails.root.join('ee/spec/fixtures/arkose/successfully_solved_ec_response.json'))
    )
    response = Arkose::VerifyResponse.new(json)
    ServiceResponse.success(payload: { response: response })
  end

  let(:failed_service_response) do
    json = Gitlab::Json.parse(File.read(Rails.root.join('ee/spec/fixtures/arkose/invalid_token.json')))
    response = Arkose::VerifyResponse.new(json)
    ServiceResponse.error(message: response.error)
  end

  let(:service_response) { successful_service_response }
  let(:arkose_status_response) { ServiceResponse.success }

  before do
    allow(::Arkose::Settings).to receive(:enabled?).and_return(true)

    allow_next_instance_of(Arkose::TokenVerificationService) do |instance|
      allow(instance).to receive(:execute).and_return(service_response)
    end

    allow_next_instance_of(::Arkose::StatusService) do |instance|
      allow(instance).to receive(:execute).and_return(arkose_status_response)
    end
  end

  subject(:create_user) { post registration_path, params: params }

  shared_examples 'creates the user' do
    it 'creates the user' do
      create_user

      created_user = User.find_by_email(user_attrs[:email])
      expect(created_user).not_to be_nil
    end
  end

  shared_examples 'renders new action with an alert flash' do
    it 'renders new action with an alert flash', :aggregate_failures do
      create_user

      expect(flash[:alert]).to eq(
        s_('Session|There was a error loading the user verification challenge. Refresh to try again.')
      )
      expect(response).to render_template(:new)
    end
  end

  context 'when arkose_labs_token verification succeeds' do
    it_behaves_like 'creates the user'

    it "records the user's data from Arkose Labs" do
      expect { create_user }.to change { UserCustomAttribute.count }.from(0)
    end

    it 'logs challenge solved event', :aggregate_failures do
      expect(Gitlab::AppLogger).to receive(:info).with(an_instance_of(String))
      expect(Gitlab::AppLogger).to receive(:info).with(
        hash_including(
          username: user_attrs[:username],
          message: "Arkose challenge",
          event: "interactive challenge solved"
        )
      )

      create_user
    end
  end

  context 'when verification fails' do
    let(:service_response) { ServiceResponse.error(message: 'Captcha was not solved') }

    it_behaves_like 'renders new action with an alert flash'

    it "does not record the user's data from Arkose Labs" do
      expect(Arkose::RecordUserDataService).not_to receive(:new)

      create_user
    end
  end

  context 'when user is not persisted' do
    before do
      create(:user, email: user_attrs[:email])
    end

    it "does not record the user's data from Arkose Labs" do
      expect(Arkose::RecordUserDataService).not_to receive(:new)

      # try to create a user with duplicate email
      create_user
    end
  end

  shared_examples 'skips verification and data recording' do
    it 'skips verification and data recording', :aggregate_failures do
      expect(Arkose::TokenVerificationService).not_to receive(:new)
      expect(Arkose::RecordUserDataService).not_to receive(:new)

      create_user
    end
  end

  context 'when feature is disabled' do
    before do
      allow(::Arkose::Settings).to receive(:enabled?).and_return(false)
    end

    it_behaves_like 'creates the user'

    it_behaves_like 'skips verification and data recording'

    context 'when reCAPTCHA is enabled' do
      before do
        stub_application_setting(recaptcha_enabled: true)
      end

      it_behaves_like 'creates the user'

      context 'when reCAPTCHA verification fails' do
        before do
          allow_next_instance_of(described_class) do |controller|
            allow(controller).to receive(:verify_recaptcha).and_return(false)
          end
        end

        it 'does not create the user' do
          create_user

          expect(User.find_by(email: user_attrs[:email])).to be_nil
          expect(flash[:alert]).to eq(_('There was an error with the reCAPTCHA. Please solve the reCAPTCHA again.'))
        end
      end
    end
  end

  context 'when arkose_labs_token verification fails' do
    let(:service_response) { failed_service_response }

    context 'when arkose is operational' do
      it_behaves_like 'renders new action with an alert flash'

      it 'skips data recording' do
        expect(Arkose::RecordUserDataService).not_to receive(:new)

        create_user
      end

      it 'logs the event' do
        expect(Gitlab::AppLogger).to receive(:info).with(
          hash_including(
            message: 'Sign-up blocked',
            reason: 'arkose token is missing in request',
            username: user_attrs[:username]
          )
        )

        create_user
      end
    end

    context 'when arkose is experiencing an outage' do
      let(:arkose_status_response) { ServiceResponse.error(message: 'Arkose outage') }

      it_behaves_like 'creates the user'

      it 'logs the event' do
        allow(Gitlab::AppLogger).to receive(:info)
        expect(Gitlab::AppLogger).to receive(:info).with(
          hash_including(
            message: 'Sign-up verification skipped',
            reason: 'arkose is experiencing an outage',
            username: user_attrs[:username]
          )
        )

        create_user
      end
    end
  end
end
