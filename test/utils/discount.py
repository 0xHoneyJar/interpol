import argparse


# Calculates a discount on an amount based on badges percentage
def main(args):
    amount = args.amount
    badges_percentage = args.badges_percentage
    protocol_fees = args.protocol_fees

    if amount is None or badges_percentage is None or protocol_fees is None:
        print("Both amount, badges_percentage and protocol_fees are required.")
        return

    # compute protocol fees first which is what we are discounting
    protocol_fees = int(amount * protocol_fees / 10000)

    # Calculate discount: 0.69 * badges_percentage (in bps)
    discount_bps = int(0.69 * badges_percentage)
    
    # Cap the discount at 69% (6900 bps)
    discount_bps = min(discount_bps, 6900)
    
    # Apply the discount to the fees
    discounted_amount = int(protocol_fees * (10000 - discount_bps) / 10000)
    
    # Format the result as a 64-character hex string
    discounted_amount_hex = "{:064x}".format(discounted_amount)
    print(discounted_amount_hex)


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--amount", type=int, required=True
    )  # amount to apply discount to
    parser.add_argument(
        "--badges-percentage", type=int, required=True
    )  # badges percentage in bps (basis points)
    parser.add_argument(
        "--protocol-fees", type=int, required=True
    )
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    main(args)
