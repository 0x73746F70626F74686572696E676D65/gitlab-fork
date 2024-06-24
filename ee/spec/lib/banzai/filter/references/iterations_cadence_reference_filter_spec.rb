# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Banzai::Filter::References::IterationsCadenceReferenceFilter, :aggregate_failures, feature_category: :team_planning do
  include FilterSpecHelper

  shared_examples 'reference parsing' do
    let(:text) { "Check #{reference}" }
    let(:filtered_text) { "Check #{cadence.to_reference}" }

    it 'links to a valid reference' do
      expect(doc(text).css('a').first.attr('href')).to eq(urls.group_iteration_cadences_url(group, cadence))
    end

    it 'links with adjacent text' do
      expect(doc(text).text).to eq(filtered_text)
    end

    it 'includes default classes' do
      expect(doc(text).css('a').first.attr('class')).to eq('gfm gfm-iterations_cadence')
    end

    it 'includes a data-iterations-cadence attribute' do
      link = doc(text).css('a').first

      expect(link).to have_attribute('data-iterations-cadence')
      expect(link.attr('data-iterations-cadence')).to eq(cadence.id.to_s)
    end

    it 'includes a data-group attribute' do
      link = doc(text).css('a').first

      expect(link).to have_attribute('data-group')
      expect(link.attr('data-group')).to eq(group.id.to_s)
    end

    it 'includes a data-original attribute' do
      link = doc(text).css('a').first

      expect(link).to have_attribute('data-original')
      expect(link.attr('data-original')).to eq(reference)
    end
  end

  let_it_be(:group) { create(:group) }
  let_it_be(:cadence) { create(:iterations_cadence, group: group, title: "cadence") }

  let(:urls) { Gitlab::Routing.url_helpers }
  let(:cadence_url) { urls.group_iteration_cadences_url(group, cadence) }

  it 'ignores invalid cadence IDs' do
    text = "Check [cadence:#{non_existing_record_id}]"

    expect(doc(text).to_s).to include(ERB::Util.html_escape_once(text))
  end

  it 'ignores out of range cadence IDs' do
    text = "Check [cadence:1161452270761535925900804973910297]"

    expect(doc(text).to_s).to include(ERB::Util.html_escape_once(text))
  end

  context 'when using ID as reference' do
    it_behaves_like 'reference parsing' do
      let(:reference) { cadence.to_reference }

      # Note: only relevant when using ID as reference.
      # HTML titles are not parsable and cannot be used as reference as with Label.
      context 'when parsing reference with HTML title' do
        let_it_be(:unescaped_title) { %(""></a>whatever<a title=") }
        let_it_be(:cadence) { create(:iterations_cadence, group: group, title: unescaped_title) }

        let(:escaped_title) { "&gt;&lt;/a&gt;whatever&lt;a title=" }

        it 'includes escaped title attribute' do
          expect(doc(text).to_html).to include(escaped_title)
          expect(doc(text).to_html).not_to include(unescaped_title)
        end
      end
    end
  end

  context 'when using title as reference' do
    it_behaves_like 'reference parsing' do
      let(:reference) { "[cadence:\"#{cadence.title}\"]" }
    end

    it_behaves_like 'reference parsing' do
      let(:reference) { "[cadence:cadence]" }
    end
  end

  def doc(text)
    context = { project: nil, group: group }

    reference_filter(text, context)
  end

  describe 'checking N+1' do
    let_it_be(:another_group) { create(:group) }
    let_it_be(:another_cadence) { create(:iterations_cadence, group: another_group) }
    let(:context) { { project: nil, group: group } }

    it 'does not have N+1 per multiple references', :use_sql_query_cache do
      markdown = cadence.to_reference

      # warm up
      reference_filter(markdown, context)

      control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
        reference_filter(markdown, context)
      end

      expect(control.count).to eq 1

      markdown = "#{cadence.to_reference} #{cadence.to_reference(format: :title)} #{another_cadence.to_reference} #{another_cadence.to_reference(format: :title)}" # rubocop:disable Layout/LineLength -- readability

      expect { reference_filter(markdown, context) }.not_to exceed_all_query_limit(1)
    end
  end
end
