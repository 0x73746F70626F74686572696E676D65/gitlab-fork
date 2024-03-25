import { s__ } from '~/locale';

export const TABLE_FIELDS = [
  { key: 'id', label: s__('MemberRole|ID') },
  { key: 'name', label: s__('MemberRole|Name') },
  { key: 'description', label: s__('MemberRole|Description') },
  { key: 'baseRole', label: s__('MemberRole|Base role') },
  {
    key: 'permissions',
    label: s__('MemberRole|Custom permissions'),
    tdClass: 'gl-white-space-nowrap',
  },
  {
    key: 'membersCount',
    label: s__('MemberRole|Member count'),
    thClass: 'gl-w-12 gl-white-space-nowrap',
    tdClass: 'gl-text-right',
  },
  {
    key: 'actions',
    label: s__('MemberRole|Actions'),
    thClass: 'gl-w-12',
    tdClass: 'gl-text-right gl-p-3!',
  },
];
