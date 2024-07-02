# frozen_string_literal: true

module QA
  RSpec.describe 'Secure', :skip_live_env, :runner, product_group: :dynamic_analysis do
    describe 'On Demand DAST' do
      let!(:test_project) do
        create(:project, :with_readme, name: 'on-demand-dast-project', description: 'On Demand DAST Project')
      end

      let!(:runner) do
        create(:project_runner,
          project: test_project,
          name: "runner-for-#{test_project.name}",
          executor: :docker)
      end

      let!(:webgoat) do
        Service::DockerRun::Webgoat.new
      end

      let(:vulnerability_name) do
        'Content-Security-Policy analysis'
      end

      let(:scan_name) do
        'Test scan 1'
      end

      let(:edited_scan_name) do
        'Edited scan 1'
      end

      before do
        webgoat.register!
        Resource::Repository::ProjectPush.fabricate! do |push|
          push.project = test_project
          push.file_name = '.gitlab-ci.yml'
          push.file_content = <<~YML
            stages:          # List of stages for jobs, and their order of execution
              - build

            build-job:       # This job runs in the build stage, which runs first.
              stage: build
              script:
                - echo "Compiling the code..."
          YML
          push.commit_message = 'Commit .gitlab-ci.yml'
          push.new_branch = false
        end

        # observe pipeline creation
        Flow::Login.sign_in_unless_signed_in
        test_project.visit!
        Flow::Pipeline.wait_for_latest_pipeline(status: 'Passed', wait: 600)
      end

      after do
        runner&.remove_via_api!
        webgoat&.remove!
      end

      context 'when a scan is ran' do
        it 'populates On Demand scan history and vulnerability report',
          testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/448336' do
          webgoat_url = "http://#{webgoat.ip_address}:8080/WebGoat/login"
          Flow::Login.sign_in_unless_signed_in
          test_project.visit!
          Page::Project::Menu.perform(&:go_to_on_demand_scans)

          EE::Page::Project::Secure::OnDemandScans.perform(&:click_new_scan_link)
          EE::Page::Project::Secure::NewOnDemandScan.perform do |new_on_demand_scan|
            new_on_demand_scan.enter_scan_name(scan_name)
            new_on_demand_scan.create_scanner_profile('Test profile 1')
            new_on_demand_scan.create_site_profile('Test site profile 1', webgoat_url)
            new_on_demand_scan.save_and_run_scan
          end

          Support::Waiter.wait_until(max_duration: 300, sleep_interval: 1) do
            test_project.pipelines.length > 1
          end

          Flow::Pipeline.visit_latest_pipeline

          Page::Project::Pipeline::Show.perform do |pipeline|
            expect(pipeline).to have_job('dast')
          end

          Flow::Pipeline.wait_for_latest_pipeline(wait: 180)
          test_project.visit!
          Page::Project::Menu.perform(&:go_to_on_demand_scans)

          EE::Page::Project::Secure::OnDemandScans.perform do |on_demand_scans|
            on_demand_scans.scan_is_present(scan_name, webgoat_url)
            on_demand_scans.click_edit_scan_button
          end

          EE::Page::Project::Secure::NewOnDemandScan.perform do |new_on_demand_scan|
            new_on_demand_scan.enter_scan_name(edited_scan_name)
            new_on_demand_scan.save_scan
          end

          EE::Page::Project::Secure::OnDemandScans.perform do |on_demand_scans|
            expect(on_demand_scans.scan_is_present(edited_scan_name, webgoat_url)).to be_truthy

            on_demand_scans.delete_scan
          end

          expect(has_text?('There are no saved scans.')).to be_truthy

          # Test that a vulnerability for this URL exists in report
          # Note that further tests of this report are located at
          # qa/qa/specs/features/ee/browser_ui/10_govern/project_security_dashboard_spec.rb
          Page::Project::Menu.perform(&:go_to_vulnerability_report)

          EE::Page::Project::Secure::SecurityDashboard.perform do |security_dashboard|
            expect(security_dashboard).to have_vulnerability(description: vulnerability_name)

            security_dashboard.click_vulnerability(description: vulnerability_name)
          end

          EE::Page::Project::Secure::VulnerabilityDetails.perform do |vulnerability_details|
            aggregate_failures "testing vulnerability details - title and url are present" do
              expect(vulnerability_details).to have_vulnerability_title(title: vulnerability_name)
              expect(vulnerability_details).to have_url(url: webgoat_url)
            end
          end
        end
      end
    end
  end
end
