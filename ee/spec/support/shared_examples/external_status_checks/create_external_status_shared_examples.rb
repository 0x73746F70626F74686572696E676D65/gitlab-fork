# frozen_string_literal: true

RSpec.shared_examples_for 'create external status services' do
  context 'when parameters are invalid' do
    let(:params) { { external_url: 'external_url.text/hello.json', name: 'test' } }

    it 'is unsuccessful' do
      expect(execute.success?).to be false # execute is the named subject of the of the executed service
    end

    it 'does not create a new rule' do
      expect { execute }.not_to change { MergeRequests::ExternalStatusCheck.count }
    end
  end

  context 'when user is not permitted to create approval rule' do
    let(:action_allowed) { false }

    it 'is unsuccessful' do
      expect(execute.error?).to be true
    end

    it 'does not create a new rule' do
      expect { execute }.not_to change { MergeRequests::ExternalStatusCheck.count }
    end

    it 'responds with the expected errors' do
      expect(execute.message).to eq('Failed to create rule')
      expect(execute.payload[:errors]).to contain_exactly 'Not allowed'
    end
  end

  context 'when approval rule are created successfully' do
    it 'creates a new ExternalApprovalRule' do
      expect { execute }.to change { MergeRequests::ExternalStatusCheck.count }.by(1)
    end

    it 'is successful' do
      expect(execute.success?).to be true
    end

    it 'includes the newly created rule in its payload' do
      rule = execute.payload[:rule]

      expect(rule).to be_a(MergeRequests::ExternalStatusCheck)
      expect(rule.project).to eq(project)
      expect(rule.external_url).to eq('https://external_url.text/hello.json')
      expect(rule.name).to eq 'Test'
      expect(rule.protected_branches).to contain_exactly(protected_branch)
    end
  end

  describe 'audit events' do
    context 'when licensed' do
      before do
        stub_licensed_features(audit_events: true)
      end

      context 'when external status check save operation succeeds', :request_store do
        it 'logs an audit event' do
          expect { execute }.to change { AuditEvent.count }.by(1)
          expect(AuditEvent.last.details).to include({
            custom_message: "Added Test status check with protected branch(es) #{protected_branch.name}"
          })
        end
      end

      context 'when external status check save operation fails' do
        before do
          allow(::MergeRequests::ExternalStatusCheck).to receive(:save).and_return(false)
        end

        it 'does not log any audit event' do
          expect { execute }.not_to change { AuditEvent.count }
        end
      end
    end

    it_behaves_like 'does not create audit event when not licensed'
  end
end
