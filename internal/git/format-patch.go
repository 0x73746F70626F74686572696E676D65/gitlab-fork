package git

import (
	"fmt"
	"net/http"

	"github.com/golang/protobuf/jsonpb"
	pb "gitlab.com/gitlab-org/gitaly-proto/go"

	"gitlab.com/gitlab-org/gitlab-workhorse/internal/gitaly"
	"gitlab.com/gitlab-org/gitlab-workhorse/internal/helper"
	"gitlab.com/gitlab-org/gitlab-workhorse/internal/senddata"
)

type patch struct{ senddata.Prefix }
type patchParams struct {
	GitalyServer    gitaly.Server
	RawPatchRequest string
}

var SendPatch = &patch{"git-format-patch:"}

func (p *patch) Inject(w http.ResponseWriter, r *http.Request, sendData string) {
	var params patchParams
	if err := p.Unpack(&params, sendData); err != nil {
		helper.Fail500(w, r, fmt.Errorf("SendPatch: unpack sendData: %v", err))
		return
	}

	request := &pb.RawPatchRequest{}
	if err := jsonpb.UnmarshalString(params.RawPatchRequest, request); err != nil {
		helper.Fail500(w, r, fmt.Errorf("diff.RawPatch: %v", err))
		return
	}

	diffClient, err := gitaly.NewDiffClient(params.GitalyServer)
	if err != nil {
		helper.Fail500(w, r, fmt.Errorf("diff.RawPatch: %v", err))
		return
	}

	if err := diffClient.SendRawPatch(r.Context(), w, request); err != nil {
		helper.LogError(
			r,
			&copyError{fmt.Errorf("diff.RawPatch: request=%v, err=%v", request, err)},
		)
		return
	}
}
