import { createLink } from './dependency_linker_util';

const openTag = '<span class="">';
const closeTag = '</span>';
const TAG_URL = 'https://sum.golang.org/lookup/';
const GO_PACKAGE_URL = 'https://pkg.go.dev/';

const DEPENDENCY_REGEX = new RegExp(
  /*
   * Detects dependencies inside of content that is highlighted by Highlight.js
   * Example: '<span class="">cloud.google.com/go/bigquery v1.0.1/go.mod h1:i/xbL2UlR5RvWAURpBYZTtm/cXjCha9lbfbpx4poX+o=</span>'
   * Group 1 (packageName):  'cloud.google.com/go/bigquery'
   * Group 2 (version): 'v1.0.1/go.mod'
   * Group 3 (base64url): 'i/xbL2UlR5RvWAURpBYZTtm/cXjCha9lbfbpx4poX+o='
   */
  `${openTag}(.*) (v.*) h1:(.*)${closeTag}`,
  'gm',
);

const handleReplace = (packageName, version, tag) => {
  const packageHref = `${GO_PACKAGE_URL}${packageName}`;
  const packageLink = createLink(packageHref, packageName);
  const tagHref = `${TAG_URL}${packageName}@${version.split('/go.mod')[0]}`;
  const tagLink = createLink(tagHref, tag);

  return `${openTag}${packageLink} ${version} h1:${tagLink}${closeTag}`;
};

export default (result) => {
  return result.value.replace(DEPENDENCY_REGEX, (_, packageName, version, tag) =>
    handleReplace(packageName, version, tag),
  );
};
