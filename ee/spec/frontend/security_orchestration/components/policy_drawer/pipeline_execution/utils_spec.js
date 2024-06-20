import {
  humanizeActions,
  humanizeExternalFileAction,
} from 'ee/security_orchestration/components/policy_drawer/pipeline_execution/utils';

const mockActions = [
  {
    content: {
      include: [{ project: 'gitlab-policies/js9', ref: 'main', file: 'README.md' }],
    },
  },
  {
    content: { include: [{ ref: 'main', file: 'README.md', template: 'Template.md' }] },
  },
  {
    content: { include: [{ project: 'gitlab-policies/js9', file: 'README.md' }] },
  },
  { content: { include: [{ file: 'README.md' }] } },
  { content: { include: [{}] } },
  { content: {} },
  { content: undefined },
  { scan: 'invalid' },
  { include: [['/templates/.local.yml', '/templates/.remote.yml']] },
  { include: ['/templates/.local.yml'] },
  { content: { include: [{ file: '' }] } },
];

describe('humanizeExternalFileAction', () => {
  it.each`
    action             | output
    ${mockActions[0]}  | ${{ file: 'Path: README.md', project: 'Project: gitlab-policies/js9', ref: 'Reference: main' }}
    ${mockActions[1]}  | ${{ file: 'Path: README.md', ref: 'Reference: main', template: 'Template: Template.md' }}
    ${mockActions[2]}  | ${{ file: 'Path: README.md', project: 'Project: gitlab-policies/js9' }}
    ${mockActions[3]}  | ${{ file: 'Path: README.md' }}
    ${mockActions[4]}  | ${{}}
    ${mockActions[5]}  | ${{}}
    ${mockActions[6]}  | ${{}}
    ${mockActions[7]}  | ${{}}
    ${mockActions[8]}  | ${{ local: 'Local: /templates/.local.yml', remote: 'Remote: /templates/.remote.yml' }}
    ${mockActions[9]}  | ${{ local: 'Local: /templates/.local.yml' }}
    ${mockActions[11]} | ${{}}
  `('should parse action to messages', ({ action, output }) => {
    expect(humanizeExternalFileAction(action)).toEqual(output);
  });
});

describe('humanizeActions', () => {
  it('should parse action to messages', () => {
    expect(humanizeActions(mockActions)).toEqual([
      {
        file: 'Path: README.md',
        project: 'Project: gitlab-policies/js9',
        ref: 'Reference: main',
      },
      { file: 'Path: README.md', ref: 'Reference: main', template: 'Template: Template.md' },
      { file: 'Path: README.md', project: 'Project: gitlab-policies/js9' },
      { file: 'Path: README.md' },
      { local: 'Local: /templates/.local.yml', remote: 'Remote: /templates/.remote.yml' },
      { local: 'Local: /templates/.local.yml' },
    ]);
  });
});
