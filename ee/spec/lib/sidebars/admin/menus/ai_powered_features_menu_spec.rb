# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Admin::Menus::AiPoweredFeaturesMenu, feature_category: :navigation do
  let(:user) { build_stubbed(:user, :admin) }
  let(:context) { Sidebars::Context.new(current_user: user, container: nil) }
  let(:menu) { described_class.new(context) }

  it_behaves_like 'Admin menu',
    link: '/admin/code_suggestions',
    title: s_('Admin|AI-powered features'),
    icon: 'tanuki-ai'

  it_behaves_like 'Admin menu with sub menus'

  it_behaves_like 'Admin menu with extra container html options',
    extra_container_html_options: { testid: 'admin-ai-powered-features-link' }

  describe 'Menu items' do
    let(:sub_item) { described_class.new(context).renderable_items.find { |e| e.item_id == item_id } }

    describe 'Code Suggestions' do
      let(:item_id) { :duo_pro_code_suggestions }

      it 'renders a sub item' do
        expect(sub_item.link).to eq('/admin/code_suggestions')
        expect(sub_item.title).to eq('GitLab Duo')
        expect(sub_item.active_routes).to eq({ controller: :code_suggestions })
      end
    end

    describe 'Models' do
      let(:item_id) { :duo_pro_self_hosted_models }

      it 'renders a sub item' do
        expect(sub_item.link).to eq('/admin/ai/self_hosted_models')
        expect(sub_item.title).to eq('Custom models')
        expect(sub_item.active_routes).to eq({ controller: 'admin/ai/self_hosted_models' })
      end
    end

    describe 'Features' do
      let(:item_id) { :duo_pro_features }

      it 'renders a sub item' do
        expect(sub_item.link).to eq('/admin/ai/feature_settings')
        expect(sub_item.title).to eq('Features')
        expect(sub_item.active_routes).to eq({ controller: 'admin/ai/feature_settings' })
      end
    end
  end
end
