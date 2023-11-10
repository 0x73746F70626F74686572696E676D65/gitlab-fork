import { FINDINGS_STATUS_PARSED } from '~/diffs/components/app.vue';

export const codeQualityErrorAndParsed = jest
  .fn()
  .mockResolvedValueOnce({
    data: {
      project: {
        id: 'gid://gitlab/Project/20',
        mergeRequest: {
          id: 'gid://gitlab/MergeRequest/123',
          title: 'Update file noise.rb',
          project: {
            id: 'testid',
            nameWithNamespace: 'test/name',
            fullPath: 'testPath',
          },
          hasSecurityReports: false,
          codequalityReportsComparer: {
            report: {
              status: 'FAILED',
              newErrors: [],
              resolvedErrors: [],
              existingErrors: [],
              summary: {
                errored: 0,
                resolved: 0,
                total: 0,
              },
            },
          },
          sastReport: {
            status: 'ERROR',
            report: null,
          },
        },
      },
    },
  })
  .mockResolvedValueOnce({
    data: {
      project: {
        id: 'gid://gitlab/Project/20',
        mergeRequest: {
          id: 'gid://gitlab/MergeRequest/123',
          title: 'Update file noise.rb',
          project: {
            id: 'testid',
            nameWithNamespace: 'test/name',
            fullPath: 'testPath',
          },
          hasSecurityReports: false,
          codequalityReportsComparer: {
            report: {
              status: 'FAILED',
              newErrors: [
                {
                  description:
                    'Method `more_noise_hi` has 9 arguments (exceeds 4 allowed). Consider refactoring.',
                  fingerprint: '98506525c60c9fe7cf2dd48f8f15bc32',
                  severity: 'MAJOR',
                  filePath: 'noise.rb',
                  line: 16,
                  webUrl:
                    'http://gdk.test:3000/root/code-quality-test/-/blob/091ce33570e71766c6e46bb2b8985f3072a0d047/noise.rb#L16',
                  engineName: 'structure',
                },
              ],
              resolvedErrors: [],
              existingErrors: [],
              summary: {
                errored: 12,
                resolved: 0,
                total: 12,
              },
            },
          },
          sastReport: {
            status: 'ERROR',
            report: null,
          },
        },
      },
    },
  });

export const SASTErrorAndParsedHandler = jest
  .fn()
  .mockResolvedValueOnce({
    data: {
      project: {
        id: 'gid://gitlab/Project/20',
        mergeRequest: {
          id: 'gid://gitlab/MergeRequest/123',
          title: 'Update file noise.rb',
          project: {
            id: 'testid',
            nameWithNamespace: 'test/name',
            fullPath: 'testPath',
          },
          hasSecurityReports: false,
          codequalityReportsComparer: {
            report: {
              status: 'FAILED',
              newErrors: [],
              resolvedErrors: [],
              existingErrors: [],
              summary: {
                errored: 0,
                resolved: 0,
                total: 0,
              },
            },
          },
          sastReport: {
            status: 'ERROR',
            report: null,
          },
        },
      },
    },
  })
  .mockResolvedValueOnce({
    data: {
      project: {
        id: 'gid://gitlab/Project/20',
        mergeRequest: {
          id: 'gid://gitlab/MergeRequest/123',
          title: 'Update file noise.rb',
          project: {
            id: 'testid',
            nameWithNamespace: 'test/name',
            fullPath: 'testPath',
          },
          hasSecurityReports: false,
          codequalityReportsComparer: {
            report: {
              status: 'FAILED',
              newErrors: [],
              resolvedErrors: [],
              existingErrors: [],
              summary: {
                errored: 12,
                resolved: 0,
                total: 12,
              },
            },
          },
          sastReport: {
            status: FINDINGS_STATUS_PARSED,
            report: null,
          },
        },
      },
    },
  });

export const codeQualityNewErrorsHandler = jest.fn().mockResolvedValue({
  data: {
    project: {
      id: 'gid://gitlab/Project/20',
      mergeRequest: {
        id: 'gid://gitlab/MergeRequest/123',
        title: 'Update file noise.rb',
        project: {
          id: 'testid',
          nameWithNamespace: 'test/name',
          fullPath: 'testPath',
        },
        hasSecurityReports: false,
        codequalityReportsComparer: {
          report: {
            status: 'FAILED',
            newErrors: [
              {
                description:
                  'Method `more_noise_hi` has 9 arguments (exceeds 4 allowed). Consider refactoring.',
                fingerprint: '98506525c60c9fe7cf2dd48f8f15bc32',
                severity: 'MAJOR',
                filePath: 'noise.rb',
                line: 16,
                webUrl:
                  'http://gdk.test:3000/root/code-quality-test/-/blob/091ce33570e71766c6e46bb2b8985f3072a0d047/noise.rb#L16',
                engineName: 'structure',
              },
            ],
            resolvedErrors: [],
            existingErrors: [],
            summary: {
              errored: 12,
              resolved: 0,
              total: 12,
            },
          },
        },
        sastReport: {
          status: 'ERROR',
          report: null,
        },
      },
    },
  },
});

export const SASTParsedHandler = jest.fn().mockResolvedValue({
  data: {
    project: {
      id: 'gid://gitlab/Project/20',
      mergeRequest: {
        id: 'gid://gitlab/MergeRequest/123',
        title: 'Update file noise.rb',
        project: {
          id: 'testid',
          nameWithNamespace: 'test/name',
          fullPath: 'testPath',
        },
        hasSecurityReports: false,
        codequalityReportsComparer: {
          report: {
            status: 'FAILED',
            newErrors: [],
            resolvedErrors: [],
            existingErrors: [],
            summary: {
              errored: 12,
              resolved: 0,
              total: 12,
            },
          },
        },
        sastReport: {
          status: FINDINGS_STATUS_PARSED,
          report: null,
        },
      },
    },
  },
});
