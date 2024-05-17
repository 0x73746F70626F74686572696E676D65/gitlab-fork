# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Ingestion::MarkAsResolvedService, feature_category: :vulnerability_management do
  let_it_be(:project) { create(:project) }

  describe '#execute' do
    context 'when using a vulnerability scanner' do
      let(:command) { described_class.new(scanner, ingested_ids) }
      let(:ingested_ids) { [] }
      let_it_be(:scanner) { create(:vulnerabilities_scanner, project: project) }

      it 'resolves non-generic vulnerabilities detected by the scanner' do
        vulnerability = create(:vulnerability, :sast,
          project: project,
          present_on_default_branch: true,
          resolved_on_default_branch: false,
          findings: [create(:vulnerabilities_finding, project: project, scanner: scanner)]
        )

        command.execute

        expect(vulnerability.reload).to be_resolved_on_default_branch
      end

      it 'does not resolve vulnerabilities detected by a different scanner' do
        vulnerability = create(:vulnerability, :sast, project: project, present_on_default_branch: true)

        command.execute

        expect(vulnerability.reload).not_to be_resolved_on_default_branch
      end

      context 'when a vulnerability requires manual resolution' do
        it 'does not resolve generic vulnerabilities' do
          vulnerability = create(:vulnerability, :generic, project: project)

          command.execute

          expect(vulnerability.reload).not_to be_resolved_on_default_branch
        end

        it 'does not resolve secret_detection vulnerabilities' do
          vulnerability = create(:vulnerability, :secret_detection, project: project)

          command.execute

          expect(vulnerability.reload).not_to be_resolved_on_default_branch
        end
      end

      context 'when a vulnerability is already ingested' do
        let_it_be(:ingested_vulnerability) { create(:vulnerability, project: project) }

        before do
          ingested_ids << ingested_vulnerability.id
        end

        it 'does not resolve ingested vulnerabilities' do
          command.execute

          expect(ingested_vulnerability.reload).not_to be_resolved_on_default_branch
        end
      end

      context 'when a vulnerability has been created by Continuous Vulnerability Scanning' do
        let_it_be(:cvs_scanner) do
          create(:vulnerabilities_scanner, project: project,
            name: 'CVS scanner',
            external_id: 'gitlab-sbom-vulnerability-scanner'
          )
        end

        let_it_be(:cvs_ds_vulnerability) do
          create(:vulnerability, :dependency_scanning, project: project,
            present_on_default_branch: true,
            resolved_on_default_branch: false,
            findings: [create(:vulnerabilities_finding, project: project, scanner: cvs_scanner)]
          )
        end

        let_it_be(:cvs_cs_vulnerability) do
          create(:vulnerability, :container_scanning, project: project,
            present_on_default_branch: true,
            resolved_on_default_branch: false,
            findings: [create(:vulnerabilities_finding, project: project, scanner: cvs_scanner)]
          )
        end

        context 'when ingesting vulnerabilities from a Dependency Scanning scanner' do
          using RSpec::Parameterized::TableSyntax

          where(scanner_id: described_class::DS_SCANNERS_EXTERNAL_IDS)

          with_them do
            let(:scanner) do
              create(:vulnerabilities_scanner, project: project,
                name: scanner_id,
                external_id: scanner_id
              )
            end

            context 'when mark_cvs_vulnerabilities_as_resolved FF is disabled' do
              before do
                stub_feature_flags(mark_cvs_vulnerabilities_as_resolved: false)
              end

              it 'does not resolve CVS vulnerabilities' do
                command.execute

                expect(cvs_cs_vulnerability.reload).not_to be_resolved_on_default_branch
                expect(cvs_ds_vulnerability.reload).not_to be_resolved_on_default_branch
              end
            end

            context 'when mark_cvs_vulnerabilities_as_resolved FF is enabled' do
              before do
                stub_feature_flags(mark_cvs_vulnerabilities_as_resolved: true)
              end

              it 'resolves CVS vulnerabilities of the Dependency Scanning report type' do
                command.execute

                expect(cvs_ds_vulnerability.reload).to be_resolved_on_default_branch
                expect(cvs_cs_vulnerability.reload).not_to be_resolved_on_default_branch
              end
            end
          end
        end

        context 'when ingesting vulnerabilities from a Container Scanning scanner' do
          let_it_be(:scanner) do
            create(:vulnerabilities_scanner, project: project,
              name: 'CS scanner',
              external_id: 'trivy'
            )
          end

          context 'when mark_cvs_vulnerabilities_as_resolved FF is disabled' do
            before do
              stub_feature_flags(mark_cvs_vulnerabilities_as_resolved: false)
            end

            it 'does not resolve CVS vulnerabilities' do
              command.execute

              expect(cvs_cs_vulnerability.reload).not_to be_resolved_on_default_branch
              expect(cvs_ds_vulnerability.reload).not_to be_resolved_on_default_branch
            end
          end

          context 'when mark_cvs_vulnerabilities_as_resolved FF is enabled' do
            before do
              stub_feature_flags(mark_cvs_vulnerabilities_as_resolved: true)
            end

            it 'resolves CVS vulnerabilities of the Container Scanning report type' do
              command.execute

              expect(cvs_cs_vulnerability.reload).to be_resolved_on_default_branch
              expect(cvs_ds_vulnerability.reload).not_to be_resolved_on_default_branch
            end
          end
        end

        context 'when ingesting vulnerabilities from other scanners' do
          let_it_be(:scanner) do
            create(:vulnerabilities_scanner, project: project,
              name: 'SAST scanner',
              external_id: 'semgrep'
            )
          end

          it 'does not resolve CVS vulnerabilities' do
            command.execute

            expect(cvs_cs_vulnerability.reload).not_to be_resolved_on_default_branch
            expect(cvs_ds_vulnerability.reload).not_to be_resolved_on_default_branch
          end
        end

        context 'when the vulnerability is still reported' do
          let_it_be(:scanner) do
            create(:vulnerabilities_scanner, project: project,
              name: 'CS scanner',
              external_id: 'trivy'
            )
          end

          before do
            ingested_ids << cvs_cs_vulnerability.id
          end

          it 'does not resolve CVS vulnerabilities' do
            command.execute

            expect(cvs_cs_vulnerability.reload).not_to be_resolved_on_default_branch
            expect(cvs_ds_vulnerability.reload).not_to be_resolved_on_default_branch
          end
        end
      end
    end

    context 'when a scanner is not available' do
      let(:command) { described_class.new(nil, []) }

      it 'does not resolve any vulnerabilities' do
        vulnerability = create(:vulnerability, :sast,
          project: project,
          present_on_default_branch: true,
          resolved_on_default_branch: false,
          findings: []
        )

        command.execute

        expect(vulnerability.reload).not_to be_resolved_on_default_branch
      end
    end
  end
end
