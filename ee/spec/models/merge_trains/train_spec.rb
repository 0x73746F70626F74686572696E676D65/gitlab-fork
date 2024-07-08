# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeTrains::Train, feature_category: :merge_trains do
  include MergeTrainsHelpers
  using RSpec::Parameterized::TableSyntax

  let_it_be(:target_project) { create(:project, :repository) }
  let_it_be(:merge_request) { create_merge_request_on_train(project: target_project) }

  let(:train) { described_class.new(target_project, merge_request.target_branch) }

  shared_examples 'fetches the requested trains' do
    it 'returns relevant merge trains' do
      branches = trains.map(&:target_branch)

      expect(branches).to contain_exactly(*expected_branches)
    end
  end

  describe '.all_for_project' do
    subject(:trains) { described_class.all_for_project(target_project) }

    before_all do
      create(:merge_train_car, target_project: target_project, target_branch: 'master')
      create(:merge_train_car, target_project: target_project, target_branch: 'feature-1')
      create(:merge_train_car, :merged, target_project: target_project, target_branch: 'feature-2')
      create(:merge_train_car, target_project: create(:project), target_branch: 'master')
    end

    it_behaves_like 'fetches the requested trains' do
      let(:expected_branches) { %w[master feature-1] }
    end
  end

  describe '.all_for' do
    subject(:trains) { described_class.all_for(target_project, **params) }

    before_all do
      create(:merge_train_car, target_project: target_project, target_branch: 'master')
      create(:merge_train_car, target_project: target_project, target_branch: 'master')
      create(:merge_train_car, :merged, target_project: target_project, target_branch: 'master')
      create(:merge_train_car, target_project: target_project, target_branch: 'feature-1')
      create(:merge_train_car, :merged, target_project: target_project, target_branch: 'feature-2')
      create(:merge_train_car, target_project: create(:project), target_branch: 'master')
    end

    context 'when only the project is provided' do
      let(:params) { {} }

      it_behaves_like 'fetches the requested trains' do
        let(:expected_branches) { %w[master feature-1 feature-2] }
      end
    end

    context 'when target_branches are provided' do
      let(:params) { { target_branch: %w[feature-1 feature-2] } }

      it_behaves_like 'fetches the requested trains' do
        let(:expected_branches) { %w[feature-1 feature-2] }
      end

      context 'when status is provided' do
        before do
          params[:status] = described_class::STATUSES[:completed]
        end

        it_behaves_like 'fetches the requested trains' do
          let(:expected_branches) { %w[feature-2] }
        end
      end
    end

    context 'when status is provided' do
      let(:params) { { status: described_class::STATUSES[:completed] } }

      it_behaves_like 'fetches the requested trains' do
        let(:expected_branches) { %w[feature-2] }
      end
    end
  end

  describe '.project_using_ff?' do
    subject { described_class.project_using_ff?(target_project) }

    where(:merge_trains_enabled, :ff_merge_method, :expected) do
      true  | true  | true
      true  | false | false
      false | true  | false
    end

    with_them do
      before do
        allow(target_project).to receive(:merge_trains_enabled?).and_return(merge_trains_enabled)
        allow(target_project).to receive(:ff_merge_must_be_possible?).and_return(ff_merge_method)
      end

      it { is_expected.to eq expected }
    end
  end

  describe '#refresh_async' do
    subject { train.refresh_async }

    it 'schedules a worker' do
      expect(MergeTrains::RefreshWorker)
        .to receive(:perform_async).with(train.project_id, train.target_branch)

      subject
    end
  end

  describe '#active?' do
    before_all do
      create(:merge_train_car, target_project: target_project, target_branch: 'master')
      create(:merge_train_car, :merged, target_project: target_project, target_branch: 'feature-2')
      create(:merge_train_car, target_project: create(:project), target_branch: 'master')
    end

    context 'when the train contains both completed and idle cars' do
      let(:train) do
        create(:merge_train_car, :merged, target_project: target_project, target_branch: 'master').train
      end

      it 'returns true' do
        expect(train.active?).to eq(true)
      end
    end

    context 'when the train contains only completed cars' do
      let(:train) do
        create(:merge_train_car, :merged, target_project: target_project, target_branch: 'feature-2').train
      end

      it 'returns false' do
        expect(train.active?).to eq(false)
      end
    end
  end

  describe '#completed?' do
    before_all do
      create(:merge_train_car, target_project: target_project, target_branch: 'master')
      create(:merge_train_car, :merged, target_project: target_project, target_branch: 'feature-2')
      create(:merge_train_car, target_project: create(:project), target_branch: 'master')
    end

    context 'when the train contains both completed and idle cars' do
      let(:train) do
        create(:merge_train_car, :merged, target_project: target_project, target_branch: 'master').train
      end

      it 'returns true' do
        expect(train.completed?).to eq(false)
      end
    end

    context 'when the train contains only completed cars' do
      let(:train) do
        create(:merge_train_car, :merged, target_project: target_project, target_branch: 'feature-2').train
      end

      it 'returns false' do
        expect(train.completed?).to eq(true)
      end
    end
  end

  describe '#all_cars' do
    subject { train.all_cars }

    it 'returns the merge request car' do
      is_expected.to eq([merge_request.merge_train_car])
    end

    context 'when another merge request is opened but not on merge train' do
      let!(:other_merge_request) do
        create(:merge_request,
          source_project: target_project,
          source_branch: 'improve/awesome',
          target_branch: merge_request.target_branch)
      end

      it { is_expected.to eq([merge_request.merge_train_car]) }
    end

    context 'with another open merge request on the merge train' do
      let!(:merge_request_2) do
        create_merge_request_on_train(project: target_project, source_branch: 'improve/awesome')
      end

      it 'returns both cars in order of creation' do
        is_expected.to eq([merge_request.merge_train_car, merge_request_2.merge_train_car])
      end
    end

    context 'with another open merge request that has already been merged' do
      let!(:merged_merge_request) do
        create_merge_request_on_train(project: target_project, status: :merged, source_branch: 'improve/awesome')
      end

      it 'does not return the merged car' do
        is_expected.to eq([merge_request.merge_train_car])
      end
    end
  end

  describe '#sha_exists_in_history?' do
    subject { train.sha_exists_in_history?(target_sha, limit: limit) }

    let(:target_sha) { '' }
    let(:limit) { 20 }

    context 'when there is a merge request on train' do
      let(:merge_commit_sha_1) { OpenSSL::Digest.hexdigest('SHA256', 'test-1') }
      let(:target_sha) { merge_commit_sha_1 }

      context 'when the merge request has already been merging' do
        let!(:merge_request) do
          create_merge_request_on_train(project: target_project, status: :merging, source_branch: 'improve/awesome')
        end

        before do
          merge_request.update_column(:in_progress_merge_commit_sha, merge_commit_sha_1)
        end

        it { is_expected.to eq(true) }
      end

      context 'when the merge request has already been merged' do
        let!(:merge_request) do
          create_merge_request_on_train(project: target_project, status: :merged, source_branch: 'improve/awesome')
        end

        before do
          merge_request.update_column(:merge_commit_sha, merge_commit_sha_1)
        end

        it { is_expected.to eq(true) }
      end

      context 'when the merge request has been fast-forward merged from an internal ref' do
        let!(:merge_request) do
          create_merge_request_on_train(project: target_project, status: :merged, source_branch: 'improve/awesome')
        end

        before do
          merge_request.update_column(:merged_commit_sha, merge_commit_sha_1)
        end

        it { is_expected.to eq(true) }
      end

      context 'when there is another merge request on train and it has been merged' do
        let!(:merge_request_2) do
          create_merge_request_on_train(project: target_project, status: :merged, source_branch: 'improve/awesome')
        end

        let(:merge_commit_sha_2) { OpenSSL::Digest.hexdigest('SHA256', 'test-2') }
        let(:target_sha) { merge_commit_sha_2 }

        before do
          merge_request_2.update_column(:merge_commit_sha, merge_commit_sha_2)
        end

        it { is_expected.to eq(true) }

        context 'when limit is 1' do
          let(:limit) { 1 }
          let(:target_sha) { merge_commit_sha_1 }

          it { is_expected.to eq(false) }
        end
      end

      context 'when the merge request has not been merged yet' do
        it { is_expected.to eq(false) }
      end
    end

    context 'when there are no merge requests on train' do
      it { is_expected.to eq(false) }
    end
  end

  describe '#first_car' do
    subject { train.first_car }

    let(:first) { instance_double(MergeTrains::Car) }
    let(:last) { instance_double(MergeTrains::Car) }

    let(:cars) { [first, last] }

    it 'returns the first record of the all_cars relation' do
      allow_next_instance_of(MergeTrains::Train) do |train|
        allow(train).to receive(:all_cars).and_return(cars)
      end

      expect(subject).to eq(first)
    end
  end

  describe '#car_count' do
    subject { train.car_count }

    let(:cars) { [instance_double(MergeTrains::Car), instance_double(MergeTrains::Car)] }

    it 'returns the count of the all_cars relation' do
      allow_next_instance_of(MergeTrains::Train) do |train|
        allow(train).to receive(:all_cars).and_return(cars)
      end

      expect(subject).to eq(cars.length)
    end
  end
end
