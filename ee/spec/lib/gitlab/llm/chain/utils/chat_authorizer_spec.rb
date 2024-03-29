# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Chain::Utils::ChatAuthorizer, feature_category: :duo_chat do
  context 'for saas', :saas do
    let_it_be(:group) { create(:group_with_plan, :public, plan: :ultimate_plan) }
    let_it_be_with_reload(:project) {  create(:project, group: group) }
    let_it_be_with_reload(:resource) { create(:issue, project: project) }
    let_it_be(:user) { create(:user) }
    let(:container) { project }
    let(:context) do
      Gitlab::Llm::Chain::GitlabContext.new(
        current_user: user,
        container: container,
        resource: resource,
        ai_request: nil
      )
    end

    subject(:authorizer) { described_class }

    before_all do
      group.add_developer(user)
    end

    before do
      allow(Gitlab).to receive(:org_or_com?).and_return(true)
    end

    shared_examples 'user authorization' do
      context 'when user has groups with ai available' do
        include_context 'with ai chat enabled for group on SaaS'
        it 'returns true' do
          expect(authorizer.user(user: user).allowed?).to be(true)
        end
      end

      context 'when user has no groups with ai available' do
        include_context 'with ai features disabled and licensed chat for group on SaaS'

        it 'returns true when user has no groups with ai available' do
          expect(authorizer.user(user: user).allowed?).to be(false)
          expect(authorizer.user(user: user).message).to eq('You do not have access to chat feature.')
        end
      end
    end

    describe '.context.allowed?' do
      context 'when current user is not present' do
        include_context 'with ai chat enabled for group on SaaS'
        let(:user) { nil }

        it 'returns false' do
          expect(authorizer.context(context: context).allowed?).to be(false)
        end
      end

      context 'when both resource and container are present' do
        context 'when container is authorized' do
          include_context 'with ai chat enabled for group on SaaS'

          it 'returns true if both resource and container are authorized' do
            expect(authorizer.context(context: context).allowed?).to be(true)
          end

          it 'returns false if resource is not authorized' do
            group.members.first.destroy!

            expect(authorizer.context(context: context).allowed?).to be(false)
            expect(authorizer.context(context: context).message)
              .to include('I am unable to find what you are looking for.')
          end
        end

        context 'when container is not authorized' do
          include_context 'with ai features disabled and licensed chat for group on SaaS'

          it 'returns false if container is not authorized' do
            expect(authorizer.context(context: context).allowed?).to be(false)
            expect(authorizer.context(context: context).message)
              .to eq('This feature is only allowed in groups or projects that enable this feature.')
          end
        end
      end

      context 'when only resource is present' do
        let(:context) do
          Gitlab::Llm::Chain::GitlabContext.new(
            current_user: user,
            container: nil,
            resource: resource,
            ai_request: nil
          )
        end

        context 'when resource container is authorized' do
          include_context 'with ai chat enabled for group on SaaS'

          it 'returns true' do
            expect(authorizer.context(context: context).allowed?).to be(true)
          end
        end

        context 'when container is not authorized' do
          include_context 'with ai features disabled and licensed chat for group on SaaS'

          it 'returns false' do
            expect(authorizer.context(context: context).allowed?).to be(false)
          end
        end
      end

      context 'when only container is present' do
        let(:context) do
          Gitlab::Llm::Chain::GitlabContext.new(
            current_user: nil,
            container: container,
            resource: nil,
            ai_request: nil
          )
        end

        context 'when container is authorized' do
          include_context 'with ai chat enabled for group on SaaS'

          it 'returns true' do
            expect(authorizer.context(context: context).allowed?).to be(false)
          end
        end

        context 'when container is not authorized' do
          include_context 'with ai features disabled and licensed chat for group on SaaS'

          it 'returns false' do
            expect(authorizer.context(context: context).allowed?).to be(false)
          end
        end
      end

      context 'when neither resource nor container is present' do
        let(:context) do
          Gitlab::Llm::Chain::GitlabContext.new(
            current_user: user,
            container: nil,
            resource: nil,
            ai_request: nil
          )
        end

        context 'when user is authorized' do
          include_context 'with ai chat enabled for group on SaaS'

          it 'returns true' do
            expect(authorizer.context(context: context).allowed?).to be(true)
          end
        end

        context 'when user is not authorized' do
          include_context 'with ai features disabled and licensed chat for group on SaaS'

          it 'returns false' do
            expect(authorizer.context(context: context).allowed?).to be(false)
          end
        end
      end
    end

    describe '.container' do
      shared_examples 'container authorizer' do
        before do
          allow(user).to receive(:can?).with(:access_duo_features, container).and_return(duo_features_enabled)
        end

        context 'when container has duo_features enabled' do
          let(:duo_features_enabled) { true }

          it "calls policy with the appropriate arguments" do
            expect(user).to receive(:can?).with(:access_duo_chat, container)

            authorizer.container(container: container, user: user)
          end
        end

        context 'when container has duo_features disabled' do
          let(:duo_features_enabled) { false }

          it 'returns an unauthorized response' do
            expect(authorizer.container(container: container, user: user).allowed?).to be(false)
          end
        end
      end

      it_behaves_like 'container authorizer'

      context 'with a group' do
        let(:container) { create(:group) }

        before do
          allow(user).to receive(:can?).with(:admin_all_resources).and_call_original
        end

        it_behaves_like 'container authorizer'
      end
    end

    describe '.resource' do
      context 'when resource is nil' do
        let(:resource) { nil }

        it 'returns false' do
          expect(authorizer.resource(resource: context.resource, user: context.current_user).allowed?)
            .to be(false)
        end
      end

      context 'when resource parent is not authorized' do
        include_context 'with ai features disabled and licensed chat for group on SaaS'

        it 'returns false' do
          expect(authorizer.resource(resource: context.resource, user: context.current_user).allowed?)
            .to be(false)
        end
      end

      context 'when resource container is authorized' do
        include_context 'with ai chat enabled for group on SaaS'

        it 'calls user.can? with the appropriate arguments' do
          expect(user).to receive(:can?).with('read_issue', resource)

          authorizer.resource(resource: context.resource, user: context.current_user)
        end
      end

      context 'when resource is current user' do
        context 'when user is not in any group with ai' do
          include_context 'with ai features disabled and licensed chat for group on SaaS'

          it 'returns false' do
            expect(authorizer.resource(resource: context.current_user, user: context.current_user).allowed?)
              .to be(false)
          end
        end

        context 'when user is in any group with ai' do
          include_context 'with ai chat enabled for group on SaaS'

          it 'returns true' do
            expect(authorizer.resource(resource: context.current_user, user: context.current_user).allowed?)
              .to be(true)
          end

          context 'when resource is different user' do
            let(:resource) { build(:user) }

            it 'returns false' do
              expect(authorizer.resource(resource: resource, user: context.current_user).allowed?)
                .to be(false)
            end
          end
        end
      end
    end

    describe '.user' do
      it_behaves_like 'user authorization'
    end
  end

  context 'for self-managed' do
    let_it_be(:group) { create(:group) }
    let_it_be_with_reload(:project) {  create(:project, group: group) }
    let_it_be_with_reload(:resource) { create(:issue, project: project) }
    let_it_be(:user) { create(:user) }
    let(:container) { project }
    let(:context) do
      Gitlab::Llm::Chain::GitlabContext.new(
        current_user: user,
        container: container,
        resource: resource,
        ai_request: nil
      )
    end

    subject(:authorizer) { described_class }

    before_all do
      group.add_developer(user)
    end

    shared_examples 'user authorization' do
      context 'when ai is enabled for self-managed' do
        include_context 'with experiment features enabled for self-managed'
        it 'returns true' do
          expect(authorizer.user(user: user).allowed?).to be(true)
        end
      end

      context 'when ai is disabled for self-managed' do
        include_context 'with experiment features disabled for self-managed'

        it 'returns true when user has no groups with ai available' do
          expect(authorizer.user(user: user).allowed?).to be(false)
          expect(authorizer.user(user: user).message).to eq('You do not have access to chat feature.')
        end
      end
    end

    describe '.context.allowed?' do
      context 'when both resource and container are present' do
        context 'when ai is enabled for self-managed' do
          include_context 'with experiment features enabled for self-managed'

          it 'returns true if both resource and container are authorized' do
            expect(authorizer.context(context: context).allowed?).to be(true)
          end

          it 'returns false if resource is not authorized' do
            group.members.first.destroy!

            expect(authorizer.context(context: context).allowed?).to be(false)
            expect(authorizer.context(context: context).message)
              .to include('I am unable to find what you are looking for.')
          end
        end

        context 'when ai is disabled for self-managed' do
          include_context 'with experiment features disabled for self-managed'

          it 'returns false if container is not authorized' do
            expect(authorizer.context(context: context).allowed?).to be(false)
            expect(authorizer.context(context: context).message)
              .to eq('You do not have access to chat feature.')
          end
        end
      end

      context 'when only resource is present' do
        let(:context) do
          Gitlab::Llm::Chain::GitlabContext.new(
            current_user: user,
            container: nil,
            resource: resource,
            ai_request: nil
          )
        end

        context 'when ai is enabled for self-managed' do
          include_context 'with experiment features enabled for self-managed'

          it 'returns true' do
            expect(authorizer.context(context: context).allowed?).to be(true)
          end
        end

        context 'when ai is disabled for self-managed' do
          include_context 'with experiment features disabled for self-managed'

          it 'returns false' do
            expect(authorizer.context(context: context).allowed?).to be(false)
          end
        end
      end

      context 'when only container is present' do
        let(:context) do
          Gitlab::Llm::Chain::GitlabContext.new(
            current_user: user,
            container: container,
            resource: nil,
            ai_request: nil
          )
        end

        context 'when ai is enabled for self-managed' do
          include_context 'with experiment features enabled for self-managed'

          it 'returns true' do
            expect(authorizer.context(context: context).allowed?).to be(true)
          end
        end

        context 'when ai is disabled for self-managed' do
          include_context 'with experiment features disabled for self-managed'

          it 'returns false' do
            expect(authorizer.context(context: context).allowed?).to be(false)
          end
        end
      end

      context 'when neither resource nor container is present' do
        let(:context) do
          Gitlab::Llm::Chain::GitlabContext.new(
            current_user: user,
            container: nil,
            resource: nil,
            ai_request: nil
          )
        end

        context 'when ai is enabled for self-managed' do
          include_context 'with experiment features enabled for self-managed'

          it 'returns true' do
            expect(authorizer.context(context: context).allowed?).to be(true)
          end
        end

        context 'when ai is disabled for self-managed' do
          include_context 'with experiment features disabled for self-managed'

          it 'returns false' do
            expect(authorizer.context(context: context).allowed?).to be(false)
          end
        end
      end
    end

    describe '.resource' do
      context 'when resource is nil' do
        let(:resource) { nil }

        it 'returns false' do
          expect(authorizer.resource(resource: context.resource, user: context.current_user).allowed?)
            .to be(false)
        end
      end

      context 'when ai is disabled for self-managed' do
        include_context 'with experiment features disabled for self-managed'

        it 'returns false' do
          expect(authorizer.resource(resource: context.resource, user: context.current_user).allowed?)
            .to be(false)
        end
      end

      context 'when ai is enabled for self-managed' do
        include_context 'with experiment features enabled for self-managed'

        it 'calls user.can? with the appropriate arguments' do
          expect(user).to receive(:can?).with('read_issue', resource)

          authorizer.resource(resource: context.resource, user: context.current_user)
        end
      end

      context 'when resource is current user' do
        context 'when ai is disabled for self-managed' do
          include_context 'with experiment features disabled for self-managed'

          it 'returns false' do
            expect(authorizer.resource(resource: context.current_user, user: context.current_user).allowed?)
              .to be(false)
          end
        end

        context 'when ai is enabled for self-managed' do
          include_context 'with experiment features enabled for self-managed'

          it 'returns true' do
            expect(authorizer.resource(resource: context.current_user, user: context.current_user).allowed?)
              .to be(true)
          end

          context 'when resource is different user' do
            let(:resource) { build(:user) }

            it 'returns false' do
              expect(authorizer.resource(resource: resource, user: context.current_user).allowed?)
                .to be(false)
            end
          end
        end
      end
    end

    describe '.user' do
      it_behaves_like 'user authorization'
    end
  end
end
