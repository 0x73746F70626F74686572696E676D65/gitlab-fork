# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Banzai::ReferenceParser::IterationParser do
  include ReferenceParserHelpers

  let(:parent) { create(:group) }
  let(:group) { create(:group, parent: parent) }
  let(:project) { create(:project, :public, group: group) }
  let(:user) { create(:user) }
  let(:iteration1) { create(:iteration, group: group) }
  let(:iteration2) { create(:iteration, group: parent) }
  let(:link) { empty_html_link }

  subject { described_class.new(context) }

  RSpec.shared_examples 'parses iteration references' do
    describe '#nodes_visible_to_user' do
      context 'when the link has a data-iteration attribute' do
        before do
          link['data-iteration'] = iteration1.id.to_s
        end

        it_behaves_like "referenced feature visibility", "issues", "merge_requests"
      end

      context 'when the link references an iteration in parent group' do
        before do
          link['data-iteration'] = iteration2.id.to_s
        end

        it_behaves_like "referenced feature visibility", "issues", "merge_requests"
      end
    end

    describe '#referenced_by' do
      describe 'when the link has a data-iteration attribute' do
        context 'using an existing iteration ID' do
          it 'returns an Array of iterations' do
            link['data-iteration'] = iteration1.id.to_s

            expect(subject.referenced_by([link])).to eq([iteration1])
          end
        end

        context 'using an iteration from parent group' do
          it 'returns an Array of iterations' do
            link['data-iteration'] = iteration2.id.to_s

            expect(subject.referenced_by([link])).to eq([iteration2])
          end
        end

        context 'using a non-existing iteration ID' do
          it 'returns an empty Array' do
            link['data-iteration'] = ''

            expect(subject.referenced_by([link])).to eq([])
          end
        end
      end
    end
  end

  context 'in project context' do
    let(:context) { Banzai::RenderContext.new(project, user) }

    it_behaves_like 'parses iteration references'
  end

  context 'in group context' do
    let(:context) { Banzai::RenderContext.new(project.group, user) }

    it_behaves_like 'parses iteration references'
  end
end
