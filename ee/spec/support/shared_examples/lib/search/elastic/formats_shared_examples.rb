# frozen_string_literal: true

RSpec.shared_examples 'a query formatted for count_only' do
  it 'does not apply size by default' do
    expect(subject).not_to include(size: 0)
  end

  context 'when count_only is true in options' do
    let(:options) { base_options.merge(count_only: true) }

    it 'does applies size' do
      expect(subject).to include(size: 0)
    end
  end
end

RSpec.shared_examples 'a query that sets source_fields' do
  it 'applies the source field' do
    expect(subject).to include(_source: ['id'])
  end
end
