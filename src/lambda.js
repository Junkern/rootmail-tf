const { simpleParser } = require('mailparser')
const { DateTime } = require('luxon')
const { GetObjectCommand, S3Client } = require('@aws-sdk/client-s3')
const { PutParameterCommand, CreateOpsItemCommand, SSMClient } = require('@aws-sdk/client-ssm')

const s3 = new S3Client({ region: process.env.BucketRegion })
const ssm = new SSMClient({ region: process.env.AWS_REGION })

const filteredEmailSubjects = [
  'Your AWS Account is Ready - Get Started Now',
  'Welcome to Amazon Web Services',
]

function log(option) {
  console.log("Log output:" + JSON.stringify(option, null, 2))
}

exports.handler = async (event, context) => {
  log({
    event,
    level: 'debug',
  })

  for (const record of event.Records) {
    const id = record.ses.mail.messageId
    const key = `RootMail/${id}`
    const { receipt } = record.ses

    log({
      id,
      level: 'debug',
      key,
      msg: 'processing mail',
    })

    const verdicts = {
      dkim: receipt.dkimVerdict.status,
      spam: receipt.spamVerdict.status,
      spf: receipt.spfVerdict.status,
      virus: receipt.virusVerdict.status,
    }

    for (const [k, v] of Object.entries(verdicts)) {
      if (v !== 'PASS') {
        log({
          class: k,
          id,
          key,
          level: 'warn',
          msg: 'verdict failed - ops santa item skipped',
        })
        return
      }
    }

    const response = await s3.send(new GetObjectCommand({
      Bucket: process.env.EmailBucket,
      Key: key,
    }))

    const msg = await simpleParser(response.Body)

    const title = msg.subject
    const source = event.Records[0].ses.mail.destination[0]

    if (title === 'Amazon Web Services Password Assistance') {
      const description = msg.html
      const pwResetLink = description.match(/(https:\/\/signin.aws.amazon.com\/resetpassword.*?)(?=<br>)/)[0]
      const rootmailIdentifier = `/rootmail/pw_reset_link/${source.split('@')[0].split('root+')[1]}`

      const putParameterCommand = new PutParameterCommand({
        Name: rootmailIdentifier,
        Value: pwResetLink,
        Overwrite: true,
        Type: 'String',
        Tier: 'Advanced',
        Policies: JSON.stringify([
          {
            Type: 'Expiration',
            Version: '1.0',
            Attributes: {
              Timestamp: DateTime.now().plus({ minutes: 10 }).toISO(),
            },
          },
        ]),
      })

      await ssm.send(putParameterCommand)
      log({status: 'Success', message: 'Created entry in Parameter store'})
      return // no ops item for now
    }

    if (filteredEmailSubjects.includes(title)) {
      log({
        level: 'info',
        msg: 'filtered email',
        title,
      })
      return
    }

    let description = msg.body
    if (msg.html) {
      description = msg.html
    }

    const truncatedTitle = title.slice(0, 1020) + ' ...'.repeat(title.length > 1020)
    const truncatedDescription = description.slice(0, 1020) + ' ...'.repeat(description.length > 1020)
    const truncatedSource = source.slice(0, 60) + ' ...'.repeat(source.length > 60)

    const operationalData = {
      '/aws/dedup': {
        Value: JSON.stringify({
          dedupString: id,
        }),
        Type: 'SearchableString',
      },
      '/aws/resources': {
        Value: JSON.stringify([
          {
            arn: `${process.env.EmailBucketArn}/${key}`,
          },
        ]),
        Type: 'SearchableString',
      },
    }

    await ssm.send(
      new CreateOpsItemCommand({
        OperationalData: operationalData,
        Description: truncatedDescription,
        Source: truncatedSource,
        Title: truncatedTitle
      })
    )
  }
}
