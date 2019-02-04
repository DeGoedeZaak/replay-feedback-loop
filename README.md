# replay-feedback-loop

A very simple app to replay reports from AWS to the `/mailings/feedback-loop` endpoint in Identity.

## Why?
Use case for this app is that we hadn't correctly set up the handling of bounces and spam-reports on AWS. This meant
our `/mailings/feedback-loop` was not triggered and thus the bounces and spam-reports were not processed in Identity.

We did get an email from these notifications, so I've built this app to be able to extract the correct info from these
emails and re-submit them to the `/mailings/feedback-loop` endpoint in Identity.

## How does it work
This app has 2 endpoints that can be reached with a POST request.

### `POST /complaint`
This endpoint can be used to post the contents of a complaint email to. You will receive these kind of emails when you've checked the "Email Feedback Forwarding" checkbox in AWS SES.

The endpoint assumes a plaintext payload (the original email), sent as parameter with the name `message`. The plaintext has a format like this:

```
---------- Forwarded message ----------
From: Someone at Your Org <foo@example.com>
To: <bar@example.com>
Cc:
Bcc:
Date: Fri, 14 Dec 2018 16:21:06 +0000
Subject: Some subject

<body of your email>
```

It will extract all `To:` lines from the email message and return the last one. So in case the email has been forwarded multiple times before you process it, it will always extract the original recipient, which should be the one the should be unsubscribed.

### `POST /json`
This endpoint can be used when you've got notification emails from AWS SNS with the actual JSON payload that was also sent directly to Identity endpoint.

> Please make sure that you're not sending an actual `application/json` request to this app, it assumes plaintext (the email body), not JSON!

The endpoint assumes a plaintext payload (the original email), sent as parameter with the name `message`. The plaintext has a format like this:

```
{"notificationType":"Bounce","bounce":{"bounceType":"Permanent","bounceSubType":"General","bouncedRecipients":[{"emailAddress":"foo@example.com","action":"failed","status":"5.1.1","diagnosticCode":"smtp; 550 5.1.1 <foo@example.com>: Recipient address rejected: User unknown in virtual mailbox table"}],"timestamp":"2019-01-21T10:03:55.896Z","feedbackId":"010201686fddd647-a1a8cc05-bbde-41bf-9977-1468551a3824-000000","remoteMtaIp":"188.40.16.121","reportingMTA":"dsn; a3-23.smtp-out.eu-west-1.amazonses.com"},"mail":{"timestamp":"2019-01-21T10:03:53.000Z","source":"\"Someone at Your Org\" <bar@example.com>","sourceArn":"arn:aws:ses:eu-west-1:022161155994:identity/bar@example.com","sourceIp":"127.0.0.1","sendingAccountId":"022161155994","messageId":"762361686fddce49-0fd31eca-b191-419c-996e-5f4c54286a97-000000","destination":["foo@example.com"]}}

--
If you wish to stop receiving notifications from this topic, please click or visit the link below to unsubscribe:
https://sns.eu-west-1.amazonaws.com/unsubscribe.html?SubscriptionArn=arn:aws:sns:eu-west-1:022161155994:bounce:41564d74-b488-4c20-a266-4e2fda67582c&Endpoint=baz@example.com

Please do not reply directly to this email. If you have any questions or comments regarding this email, please contact us at https://aws.amazon.com/support
```

The endpoint has a few fallbacks in case the JSON is malformed (e.g. by having random newlines, or be being partially cut-off by your mail client).

## Our setup
We ran this app the following way:

1. Deploy this app to Heroku
2. Create a zap at [Zapier.com][1], that listens to an email address and posts the email body content to the right endpoint of this app (we made 2 zaps for each endpoint, each with their own email address)
3. We used [Multi-Email-Forwarder][2] from [CloudHQ][3] to easily forward all the emails from our GMail Inbox to the special Zapier email address. This can take a while, but it's better than forwarding them all manually.

That's it. Be sure to check your logs in Identity if all bounces and spam-reports are handled appropriately!

[1]: https://zapier.com
[2]: https://www.multi-email-forward.com
[3]: https://cloudhq.net
