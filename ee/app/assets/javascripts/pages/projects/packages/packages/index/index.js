import initPackageList from 'ee/packages/list/packages_list_app_bundle';

document.addEventListener('DOMContentLoaded', () => {
  if (document.getElementById('js-vue-packages-list')) {
    initPackageList();
  }
});
