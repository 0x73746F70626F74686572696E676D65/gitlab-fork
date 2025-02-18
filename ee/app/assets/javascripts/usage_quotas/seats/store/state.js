export default ({
  namespaceId = null,
  namespaceName = null,
  seatUsageExportPath = null,
  addSeatsHref = '',
  hasNoSubscription = null,
  maxFreeNamespaceSeats = null,
  explorePlansPath = '',
  enforcementFreeUserCapEnabled = false,
} = {}) => ({
  isLoadingBillableMembers: false,
  isLoadingGitlabSubscription: false,
  isChangingMembershipState: false,
  isRemovingBillableMember: false,
  hasError: false,
  namespaceId,
  namespaceName,
  seatUsageExportPath,
  members: [],
  total: null,
  planCode: null,
  planName: null,
  page: null,
  perPage: null,
  billableMemberToRemove: null,
  userDetails: {},
  search: null,
  sort: 'last_activity_on_desc',
  seatsInSubscription: null,
  seatsInUse: null,
  maxSeatsUsed: null,
  seatsOwed: null,
  hasNoSubscription,
  addSeatsHref,
  maxFreeNamespaceSeats,
  explorePlansPath,
  hasLimitedFreePlan: enforcementFreeUserCapEnabled,
  hasReachedFreePlanLimit: null,
  activeTrial: false,
  subscriptionEndDate: null,
  subscriptionStartDate: null,
});
