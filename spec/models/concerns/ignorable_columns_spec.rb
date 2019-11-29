# frozen_string_literal: true

require 'spec_helper'

describe IgnorableColumns do
  let(:record_class) do
    Class.new(ApplicationRecord) do
      include IgnorableColumns
    end
  end

  subject { record_class }

  it 'adds columns to ignored_columns' do
    expect do
      subject.ignore_columns(:name, :created_at, remove_after: '2019-12-01', remove_with: '12.6')
    end.to change { subject.ignored_columns }.from([]).to(%w(name created_at))
  end

  it 'adds columns to ignored_columns (array version)' do
    expect do
      subject.ignore_columns(%i[name created_at], remove_after: '2019-12-01', remove_with: '12.6')
    end.to change { subject.ignored_columns }.from([]).to(%w(name created_at))
  end

  it 'requires remove_after attribute to be set' do
    expect { subject.ignore_columns(:name, remove_after: nil, remove_with: 12.6) }.to raise_error(ArgumentError, /Please indicate/)
  end

  it 'requires remove_with attribute to be set' do
    expect { subject.ignore_columns(:name, remove_after: '2019-12-01', remove_with: nil) }.to raise_error(ArgumentError, /Please indicate/)
  end

end