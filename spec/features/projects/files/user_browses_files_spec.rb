# frozen_string_literal: true

require "spec_helper"

RSpec.describe "User browses files", :js do
  include RepoHelpers

  let(:fork_message) do
    "You're not allowed to make changes to this project directly. "\
    "A fork of this project has been created that you can make changes in, so you can submit a merge request."
  end

  let(:project) { create(:project, :repository, name: "Shop") }
  let(:project2) { create(:project, :repository, name: "Another Project", path: "another-project") }
  let(:tree_path_root_ref) { project_tree_path(project, project.repository.root_ref) }
  let(:user) { project.first_owner }

  before do
    sign_in(user)
  end

  it "shows last commit for current directory", :js do
    visit(tree_path_root_ref)

    click_link("files")

    last_commit = project.repository.last_commit_for_path(project.default_branch, "files")

    page.within(".commit-detail") do
      expect(page).to have_content(last_commit.short_id).and have_content(last_commit.author_name)
    end
  end

  context "when browsing the master branch", :js do
    before do
      visit(tree_path_root_ref)
    end

    it "shows files from a repository" do
      expect(page).to have_content("VERSION")
                 .and have_content(".gitignore")
                 .and have_content("LICENSE")
    end

    it "shows the `Browse Directory` link" do
      click_link("files")

      page.within('.repo-breadcrumb') do
        expect(page).to have_link('files')
      end

      click_link("History")

      expect(page).to have_link("Browse Directory").and have_no_link("Browse Code")
    end

    it "shows the `Browse File` link" do
      page.within(".tree-table") do
        click_link("README.md")
      end

      click_link("History")

      expect(page).to have_link("Browse File").and have_no_link("Browse Files")
    end

    it "shows the `Browse Files` link" do
      click_link("History")

      expect(page).to have_link("Browse Files").and have_no_link("Browse Directory")
    end

    it "redirects to the permalink URL" do
      click_link(".gitignore")
      click_link("Permalink")

      permalink_path = project_blob_path(project, "#{project.repository.commit.sha}/.gitignore")

      expect(current_path).to eq(permalink_path)
    end
  end

  context "when browsing the `markdown` branch", :js do
    context "when browsing the root" do
      before do
        visit(project_tree_path(project, "markdown"))
      end

      it "shows correct files and links" do
        expect(current_path).to eq(project_tree_path(project, "markdown"))
        expect(page).to have_content("README.md")
          .and have_content("CHANGELOG")
          .and have_content("Welcome to GitLab GitLab is a free project and repository management application")
          .and have_link("GitLab API doc")
          .and have_link("GitLab API website")
          .and have_link("Rake tasks")
          .and have_link("backup and restore procedure")
          .and have_link("GitLab API doc directory")
          .and have_link("Maintenance")
          .and have_header_with_correct_id_and_link(2, "Application details", "application-details")
          .and have_link("empty", href: "")
          .and have_link("#id", href: "#id")
          .and have_link("/#id", href: project_blob_path(project, "markdown/README.md", anchor: "id"))
          .and have_link("README.md#id", href: project_blob_path(project, "markdown/README.md", anchor: "id"))
          .and have_link("d/README.md#id", href: project_blob_path(project, "markdown/db/README.md", anchor: "id"))
      end

      it "shows correct content of file" do
        click_link("GitLab API doc")

        expect(current_path).to eq(project_blob_path(project, "markdown/doc/api/README.md"))
        expect(page).to have_content("All API requests require authentication")
          .and have_content("Contents")
          .and have_link("Users")
          .and have_link("Rake tasks")
          .and have_header_with_correct_id_and_link(1, "GitLab API", "gitlab-api")

        click_link("Users")

        expect(current_path).to eq(project_blob_path(project, "markdown/doc/api/users.md"))
        expect(page).to have_content("Get a list of users.")

        page.go_back

        click_link("Rake tasks")

        expect(current_path).to eq(project_tree_path(project, "markdown/doc/raketasks"))
        expect(page).to have_content("backup_restore.md").and have_content("maintenance.md")

        click_link("maintenance.md")

        expect(current_path).to eq(project_blob_path(project, "markdown/doc/raketasks/maintenance.md"))
        expect(page).to have_content("bundle exec rake gitlab:env:info RAILS_ENV=production")

        click_link("shop")

        page.within(".tree-table") do
          click_link("README.md")
        end

        page.go_back

        page.within(".tree-table") do
          click_link("d")
        end

        expect(page).to have_link("..", href: project_tree_path(project, "markdown/"))

        page.within(".tree-table") do
          click_link("README.md")
        end

        expect(page).to have_link("empty", href: "")
      end

      it "shows correct content of directory" do
        click_link("GitLab API doc directory")

        expect(current_path).to eq(project_tree_path(project, "markdown/doc/api"))
        expect(page).to have_content("README.md").and have_content("users.md")

        click_link("Users")

        expect(current_path).to eq(project_blob_path(project, "markdown/doc/api/users.md"))
        expect(page).to have_content("List users").and have_content("Get a list of users.")
      end
    end
  end

  context 'when commit message has markdown', :js do
    before do
      project.repository.create_file(user, 'index', 'test', message: ':star: testing', branch_name: 'master')

      visit(project_tree_path(project, "master"))
    end

    it 'renders emojis' do
      expect(page).to have_selector('gl-emoji', count: 2)
    end
  end

  context "when browsing a `improve/awesome` branch", :js do
    before do
      visit(project_tree_path(project, "improve/awesome"))
    end

    it "shows files from a repository" do
      expect(page).to have_content("VERSION")
        .and have_content(".gitignore")
        .and have_content("LICENSE")

      click_link("files")

      page.within('.repo-breadcrumb') do
        expect(page).to have_link('files')
      end

      click_link("html")

      page.within('.repo-breadcrumb') do
        expect(page).to have_link('html')
      end

      expect(page).to have_link('500.html')
    end
  end

  context "when browsing a `Ääh-test-utf-8` branch", :js do
    before do
      project.repository.create_branch('Ääh-test-utf-8', project.repository.root_ref)
      visit(project_tree_path(project, "Ääh-test-utf-8"))
    end

    it "shows files from a repository" do
      expect(page).to have_content("VERSION")
        .and have_content(".gitignore")
        .and have_content("LICENSE")

      click_link("files")

      page.within('.repo-breadcrumb') do
        expect(page).to have_link('files')
      end

      click_link("html")

      page.within('.repo-breadcrumb') do
        expect(page).to have_link('html')
      end

      expect(page).to have_link('500.html')
    end
  end

  context "when browsing a `test-#` branch", :js do
    before do
      project.repository.create_branch('test-#', project.repository.root_ref)
      visit(project_tree_path(project, "test-#"))
    end

    it "shows files from a repository" do
      expect(page).to have_content("VERSION")
        .and have_content(".gitignore")
        .and have_content("LICENSE")

      click_link("files")

      page.within('.repo-breadcrumb') do
        expect(page).to have_link('files')
      end

      click_link("html")

      page.within('.repo-breadcrumb') do
        expect(page).to have_link('html')
      end

      expect(page).to have_link('500.html')
    end
  end

  context "when browsing a specific ref", :js do
    let(:ref) { project_tree_path(project, "6d39438") }

    before do
      visit(ref)
    end

    it "shows files from a repository for `6d39438`" do
      expect(current_path).to eq(ref)
      expect(page).to have_content(".gitignore").and have_content("LICENSE")
    end

    it "shows files from a repository with apostroph in its name" do
      first(".js-project-refs-dropdown").click

      page.within(".project-refs-form") do
        click_link("'test'")
      end

      expect(page).to have_selector(".dropdown-toggle-text", text: "'test'")

      visit(project_tree_path(project, "'test'"))

      expect(page).not_to have_selector(".tree-commit .animation-container")
    end

    it "shows the code with a leading dot in the directory" do
      first(".js-project-refs-dropdown").click

      page.within(".project-refs-form") do
        click_link("fix")
      end

      visit(project_tree_path(project, "fix/.testdir"))

      expect(page).not_to have_selector(".tree-commit .animation-container")
    end

    it "does not show the permalink link" do
      click_link(".gitignore")

      expect(page).not_to have_link("permalink")
    end
  end

  context "when browsing a file content", :js do
    before do
      visit(tree_path_root_ref)
      wait_for_requests

      click_link(".gitignore")
    end

    it "shows a file content" do
      expect(page).to have_content("*.rbc")
    end

    it "is possible to blame" do
      click_link("Blame")

      expect(page).to have_content("*.rb")
                 .and have_content("Dmitriy Zaporozhets")
                 .and have_content("Initial commit")
                 .and have_content("Ignore DS files")

      previous_commit_anchor = "//a[@title='Ignore DS files']/parent::span/following-sibling::span/a"
      find(:xpath, previous_commit_anchor).click

      expect(page).to have_content("*.rb")
                 .and have_content("Dmitriy Zaporozhets")
                 .and have_content("Initial commit")

      expect(page).not_to have_content("Ignore DS files")
    end
  end

  context "when browsing a file with pathspec characters" do
    let(:filename) { ':wq' }
    let(:newrev) { project.repository.commit('master').sha }

    before do
      create_file_in_repo(project, 'master', 'master', filename, 'Test file')
      path = File.join('master', filename)

      visit(project_blob_path(project, path))
      wait_for_requests
    end

    it "shows raw file content in a new tab" do
      new_tab = window_opened_by {click_link 'Open raw'}

      within_window new_tab do
        expect(page).to have_content("Test file")
      end
    end
  end

  context "when browsing a raw file" do
    before do
      visit(tree_path_root_ref)
      wait_for_requests

      click_link(".gitignore")
      wait_for_requests
    end

    it "shows raw file content in a new tab" do
      new_tab = window_opened_by {click_link 'Open raw'}

      within_window new_tab do
        expect(page).to have_content("*.rbc")
      end
    end
  end
end
