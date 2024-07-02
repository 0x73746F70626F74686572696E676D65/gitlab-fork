# frozen_string_literal: true

FactoryBot.define do
  factory :security_finding, class: 'Security::Finding' do
    scanner factory: :vulnerabilities_scanner
    scan factory: :security_scan

    severity { :critical }
    uuid { SecureRandom.uuid }
    project_fingerprint { generate(:project_fingerprint) }

    transient do
      false_positive { false }
    end

    transient do
      solution { 'foo' }
    end

    transient do
      remediation_byte_offsets { [] }
    end

    transient do
      location { {} }
    end

    finding_data do
      {
        name: 'Test finding',
        description: 'The cipher does not provide data integrity update 1',
        solution: solution,
        identifiers: [],
        links: [
          {
            name: 'Cipher does not check for integrity first?',
            url: 'https://crypto.stackexchange.com/questions/31428/pbewithmd5anddes-cipher-does-not-check-for-integrity-first'
          }
        ],
        false_positive?: false_positive,
        location: location,
        evidence: {},
        assets: [],
        details: {},
        raw_source_code_extract: 'AES/ECB/NoPadding',
        remediation_byte_offsets: remediation_byte_offsets
      }
    end
  end
end
