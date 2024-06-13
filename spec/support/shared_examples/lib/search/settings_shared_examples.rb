# frozen_string_literal: true

RSpec.shared_examples 'all sections exist and have correct anchor links' do
  let(:settings) { Search::Settings.new.for_project(project) }
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }

  it 'has only valid settings sections' do
    sign_in(user)
    project.add_maintainer(user)

    current_href = nil
    settings.each do |setting|
      # This speeds up the spec by not repeatedly visiting the same page.
      if current_href != remove_anchor_from_url(setting[:href])
        visit setting[:href]
        current_href = remove_anchor_from_url(setting[:href])
      end

      expect(page).to have_content setting[:text]
      expect(page).to have_css "##{URI.parse(setting[:href]).fragment}"
    end
  end

  def remove_anchor_from_url(url)
    uri = URI.parse(url)
    uri.fragment = nil
    uri.to_s
  end
end
