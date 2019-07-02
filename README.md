# terminationspotter

A lambda function taking care of spot instances in your AWS ECS cluster.

It will search for the instance ID provided by the event in all ECS clusters on
the account and set its instance state to DRAINING so ECS can reschedule all
containers running on that instance before it gets terminated.

It can be deployed using [Terraform][terraform] and will create:

- A cloudwatch event rule matching so called 'EC2 Spot Instance Interruption Warnings'
- A lambda function that sets the instance state to DRAINING
- All needed IAM roles and policies and lambda permissions

It will trigger every time a spot instance is scheduled for termination.

## Usage

``` hcl
module "terminationspotter" {
  source = "github.com/freenowtech/terminationspotter-lambda"
}
```

[terraform]: https://terraform.io