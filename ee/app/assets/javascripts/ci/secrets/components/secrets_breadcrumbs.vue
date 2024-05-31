<script>
import { GlBreadcrumb } from '@gitlab/ui';
import { DETAILS_ROUTE_NAME } from '../constants';

export default {
  components: {
    GlBreadcrumb,
  },
  computed: {
    rootRoute() {
      const route = this.$router.options.routes.find((r) => r.meta.isRoot);
      return {
        text: route.meta.getBreadcrumbText(),
        to: { name: route.name },
      };
    },
    detailsRoute() {
      return {
        text: String(this.$route.params.id),
        to: { name: DETAILS_ROUTE_NAME },
      };
    },
    routeName() {
      return this.$route.meta.getBreadcrumbText(this.$route.params);
    },
    crumbs() {
      // start with link to root on all pages
      const crumbs = [this.rootRoute];

      // add link to secret details if route contains a secret key
      if (this.$route.params.id) {
        crumbs.push(this.detailsRoute);
      }

      // add current page (if neither root nor details)
      if (!this.$route.meta.isRoot && !this.$route.meta.isDetails && this.routeName) {
        crumbs.push({
          text: this.routeName,
          to: undefined,
        });
      }

      return crumbs;
    },
  },
};
</script>
<template>
  <gl-breadcrumb :items="crumbs" :auto-resize="false" />
</template>
