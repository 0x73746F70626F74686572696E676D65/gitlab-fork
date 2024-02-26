# frozen_string_literal: true

RSpec.shared_examples 'syncs all data from an epic to a work item' do
  it 'sets the same basic epic data to the work item', :aggregate_failures do
    subject

    epic.reload
    work_item = epic.work_item

    expect(epic).to be_persisted
    expect(work_item).to be_valid

    expect(work_item.work_item_type.name).to eq('Epic')
    expect(work_item.namespace).to eq(epic.group)
    expect(work_item.title).to eq epic.title
    expect(work_item.title_html).to eq epic.title_html
    expect(work_item.description).to eq epic.description
    expect(work_item.description_html).to eq epic.description_html
    expect(work_item.updated_by).to eq epic.updated_by
    expect(work_item.last_edited_by).to eq epic.last_edited_by
    expect(work_item.last_edited_at).to eq epic.last_edited_at
    expect(work_item.closed_by).to eq epic.closed_by
    expect(work_item.closed_at).to eq epic.closed_at
    expect(work_item.confidential).to eq epic.confidential
    expect(work_item.iid).to eq(epic.iid)
    expect(work_item.state).to eq(epic.state)
    expect(work_item.author).to eq(epic.author)
    expect(work_item.created_at).to eq(epic.created_at)
    expect(work_item.state).to eq(epic.state)
    expect(work_item.external_key).to eq(epic.external_key)
    expect(work_item.lock_version).to eq(epic.lock_version)
    expect(work_item.relative_position).to eq(epic.id)
  end

  it 'sets the same epic data to the work item association', :aggregate_failures do
    subject

    epic.reload
    work_item = epic.work_item

    if epic.color == Epic::DEFAULT_COLOR
      expect(work_item.color).to be_nil
    else
      expect(work_item.color.color).to eq(epic.color)
    end

    if epic.parent
      expect(work_item.work_item_parent).to eq(epic.parent.work_item)
      expect(work_item.parent_link.relative_position).to eq(epic.relative_position)
    else
      expect(work_item.work_item_parent).to be_nil
    end

    if epic.start_date_is_fixed
      expect(work_item.dates_source.start_date_is_fixed).to eq(epic.start_date_is_fixed)
      expect(work_item.dates_source.start_date_fixed).to eq(epic.start_date_fixed)
    end

    if epic.due_date_is_fixed
      expect(work_item.dates_source.due_date_is_fixed).to eq(epic.due_date_is_fixed)
      expect(work_item.dates_source.due_date_fixed).to eq(epic.due_date_fixed)
    end

    if epic.unauthorized_related_epics
      related_epic_issue_ids = epic.unauthorized_related_epics.map(&:issue_id)
      related_work_item_ids = work_item.related_issues(authorize: false).map(&:id)

      expect(related_work_item_ids).to match(related_epic_issue_ids)
    end

    # Data we do not want to sync yet
    expect(work_item.notes).to be_empty
    expect(work_item.labels).to be_empty
  end
end
