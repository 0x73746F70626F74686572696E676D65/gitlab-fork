package gitaly

import (
	"fmt"
	"io"

	pb "gitlab.com/gitlab-org/gitaly-proto/go"
	pbhelper "gitlab.com/gitlab-org/gitaly-proto/go/helper"

	"golang.org/x/net/context"
	"google.golang.org/grpc"
)

type SmartHTTPClient struct {
	pb.SmartHTTPClient
}

type uploadPackWriter struct {
	pb.SmartHTTP_PostUploadPackClient
}

type receivePackWriter struct {
	pb.SmartHTTP_PostReceivePackClient
}

const sendChunkSize = 16384

func (client *SmartHTTPClient) InfoRefsResponseWriterTo(ctx context.Context, repo *pb.Repository, rpc string) (io.WriterTo, error) {
	rpcRequest := &pb.InfoRefsRequest{Repository: repo}
	var c pbhelper.InfoRefsClient
	var err error

	switch rpc {
	case "git-upload-pack":
		c, err = client.InfoRefsUploadPack(ctx, rpcRequest)
	case "git-receive-pack":
		c, err = client.InfoRefsReceivePack(ctx, rpcRequest)
	default:
		return nil, fmt.Errorf("InfoRefsResponseWriterTo: Unsupported RPC: %q", rpc)
	}

	if err != nil {
		return nil, fmt.Errorf("InfoRefsResponseWriterTo: RPC call failed: %v", err)
	}

	return &pbhelper.InfoRefsClientWriterTo{c}, nil
}

func (client *SmartHTTPClient) ReceivePack(repo *pb.Repository, GlId string, clientRequest io.Reader, clientResponse io.Writer) error {
	ctx, cancelFunc := context.WithCancel(context.Background())
	defer cancelFunc()

	stream, err := client.PostReceivePack(ctx)
	if err != nil {
		return err
	}

	rpcRequest := &pb.PostReceivePackRequest{
		Repository: repo,
		GlId:       GlId,
	}

	if err := stream.Send(rpcRequest); err != nil {
		return fmt.Errorf("initial request: %v", err)
	}

	waitc := make(chan error, 1)

	go receiveGitalyResponse(stream, waitc, clientResponse, func() ([]byte, error) {
		response, err := stream.Recv()
		return response.GetData(), err
	})

	_, sendErr := io.Copy(receivePackWriter{stream}, clientRequest)
	stream.CloseSend()

	if recvErr := <-waitc; recvErr != nil {
		return recvErr
	}
	if sendErr != nil {
		return fmt.Errorf("send: %v", sendErr)
	}

	return nil
}

func (client *SmartHTTPClient) UploadPack(repo *pb.Repository, clientRequest io.Reader, clientResponse io.Writer) error {
	ctx, cancelFunc := context.WithCancel(context.Background())
	defer cancelFunc()

	stream, err := client.PostUploadPack(ctx)
	if err != nil {
		return err
	}

	rpcRequest := &pb.PostUploadPackRequest{
		Repository: repo,
	}

	if err := stream.Send(rpcRequest); err != nil {
		return fmt.Errorf("initial request: %v", err)
	}

	waitc := make(chan error, 1)

	go receiveGitalyResponse(stream, waitc, clientResponse, func() ([]byte, error) {
		response, err := stream.Recv()
		return response.GetData(), err
	})

	_, sendErr := io.Copy(uploadPackWriter{stream}, clientRequest)
	stream.CloseSend()

	if recvErr := <-waitc; recvErr != nil {
		return recvErr
	}
	if sendErr != nil {
		return fmt.Errorf("send: %v", sendErr)
	}

	return nil
}

func receiveGitalyResponse(cs grpc.ClientStream, waitc chan error, clientResponse io.Writer, receiver func() ([]byte, error)) {
	defer func() {
		close(waitc)
		cs.CloseSend()
	}()

	for {
		data, err := receiver()
		if err != nil {
			if err != io.EOF {
				waitc <- fmt.Errorf("receive: %v", err)
			}
			return
		}

		if _, err := clientResponse.Write(data); err != nil {
			waitc <- fmt.Errorf("write: %v", err)
			return
		}
	}
}

func (rw uploadPackWriter) Write(p []byte) (int, error) {
	resp := &pb.PostUploadPackRequest{Data: p}
	if err := rw.Send(resp); err != nil {
		return 0, err
	}
	return len(p), nil
}

func (rw receivePackWriter) Write(p []byte) (int, error) {
	resp := &pb.PostReceivePackRequest{Data: p}
	if err := rw.Send(resp); err != nil {
		return 0, err
	}
	return len(p), nil
}
