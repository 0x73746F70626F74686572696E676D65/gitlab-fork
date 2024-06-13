import VueRouter from 'vue-router';

import { joinPaths } from '~/lib/utils/url_utility';

import {
  ROUTE_STANDARDS_ADHERENCE,
  ROUTE_FRAMEWORKS,
  ROUTE_PROJECTS,
  ROUTE_VIOLATIONS,
  ROUTE_NEW_FRAMEWORK,
  ROUTE_EDIT_FRAMEWORK,
} from './constants';

import MainLayout from './components/main_layout.vue';

import ViolationsReport from './components/violations_report/report.vue';
import FrameworksReport from './components/frameworks_report/report.vue';
import EditFramework from './components/frameworks_report/edit_framework/edit_framework.vue';
import ProjectsReport from './components/projects_report/report.vue';
import StandardsReport from './components/standards_adherence_report/report.vue';

export function createRouter(basePath, props) {
  const {
    mergeCommitsCsvExportPath,
    globalProjectId,
    groupPath,
    rootAncestorPath,
    rootAncestorName,
    rootAncestorWebUrl,
  } = props;

  const defaultRoute = ROUTE_STANDARDS_ADHERENCE;
  const FrameworkReport = FrameworksReport;

  const routes = [
    {
      path: '/frameworks/new',
      name: ROUTE_NEW_FRAMEWORK,
      component: EditFramework,
    },
    {
      path: '/frameworks/:id',
      name: ROUTE_EDIT_FRAMEWORK,
      component: EditFramework,
    },
    {
      path: '/',
      component: MainLayout,
      children: [
        {
          path: 'standards_adherence',
          name: ROUTE_STANDARDS_ADHERENCE,
          component: StandardsReport,
          props: {
            groupPath,
            globalProjectId,
          },
        },
        {
          path: 'violations',
          name: ROUTE_VIOLATIONS,
          component: ViolationsReport,
          props: {
            mergeCommitsCsvExportPath,
            groupPath,
            globalProjectId,
          },
        },
        {
          path: 'frameworks',
          name: ROUTE_FRAMEWORKS,
          component: FrameworkReport,
          props: {
            groupPath,
            rootAncestor: {
              path: rootAncestorPath,
              webUrl: rootAncestorWebUrl,
              name: rootAncestorName,
            },
          },
        },

        {
          path: '/projects',
          name: ROUTE_PROJECTS,
          component: ProjectsReport,
          props: {
            groupPath,
            rootAncestorPath,
          },
        },
        { path: '*', redirect: { name: defaultRoute } },
      ],
    },
  ];

  return new VueRouter({
    mode: 'history',
    base: joinPaths(gon.relative_url_root || '', basePath),
    routes,
  });
}
