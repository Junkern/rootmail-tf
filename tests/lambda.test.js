require('aws-sdk-client-mock-jest')
const {mockClient} = require('aws-sdk-client-mock')
const { GetObjectCommand, S3Client } = require('@aws-sdk/client-s3')
const {sdkStreamMixin} = require('@aws-sdk/util-stream-node')
const { PutParameterCommand, CreateOpsItemCommand, SSMClient } = require('@aws-sdk/client-ssm')
const {Readable} = require('stream')
const { handler } = require('../src/lambda')

const s3Mock = mockClient(S3Client);
const ssmMock = mockClient(SSMClient);

function createSdkStream(chunks){
  const stream = new Readable();
  chunks.forEach(chunk => stream.push(`${chunk}\n`))
  stream.push(null);

  const sdkStream = sdkStreamMixin(stream);
  return sdkStream
}

describe('handler', () => {
  const mockLog = jest.fn()
  console.log = mockLog // Redirect console.log to mockLog for testing purposes

  const event = {
    Records: [
      {
        ses: {
          mail: {
            messageId: 'test-message-id',
            destination: ['rootexample'],
          },
          receipt: {
            dkimVerdict: {
              status: 'PASS',
            },
            spamVerdict: {
              status: 'PASS',
            },
            spfVerdict: {
              status: 'PASS',
            },
            virusVerdict: {
              status: 'PASS',
            },
          },
        },
      },
    ],
  }

  beforeEach(() => {
    jest.resetAllMocks()
    s3Mock.reset()
    ssmMock.reset()
  })

  it('should process email and create ops item if message subject is not filtered and not password reset', async () => {
    const sdkStream = createSdkStream(["Subject: Test", "Content-Type: text/html;\n", "<a>foobar</a>"])
    
    s3Mock.on(GetObjectCommand).resolvesOnce({
      Body: sdkStream,
    })
    
    await handler(event)

    expect(s3Mock).toHaveReceivedCommand(GetObjectCommand)
    expect(ssmMock).toHaveReceivedCommand(CreateOpsItemCommand)
  })

  it('should process email and create Parameter store string if message subject is not filtered and has password reset', async () => {
    const sdkStream = createSdkStream(["Subject: Amazon Web Services Password Assistance", "Content-Type: text/html;\n", '<a href=3D"https://signin.aws.amazon.com/resetpassword=3Dfoobandf9rjsd9">foobar<br>'])
    
    s3Mock.on(GetObjectCommand).resolvesOnce({
      Body: sdkStream,
    })
    
    await handler(event)

    expect(s3Mock).toHaveReceivedCommand(GetObjectCommand)
    expect(ssmMock).toHaveReceivedCommand(PutParameterCommand)
  })

  it('returns early if any verdict fails', async () => {
    const event = {
      Records: [
        {
          ses: {
            mail: {
              messageId: '1234',
            },
            receipt: {
              dkimVerdict: { status: 'PASS' },
              spamVerdict: { status: 'FAIL' },
              spfVerdict: { status: 'PASS' },
              virusVerdict: { status: 'PASS' },
            },
          },
        },
      ],
    };

    await handler(event);

    expect(mockLog).toHaveBeenCalledTimes(3);
  });
})