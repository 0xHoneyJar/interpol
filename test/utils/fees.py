import argparse


# Returns the fees taken to treasury, the fees given to referrer, and the amount left to withdraw for the user
def main(args):
    fees_bps = args.fees_bps
    amount = args.amount
    referrer_fees_bps = args.referrer_fees_bps
    if fees_bps is None or amount is None or referrer_fees_bps is None:
        print("All arguments are required.")
        return

    fees = int((amount * fees_bps) / 10000)
    referrer_fees = int((fees * referrer_fees_bps) / 10000)
    treasury_fees = fees - referrer_fees

    treasury_fees_hex = "{:064x}".format(treasury_fees)
    referrer_fees_hex = "{:064x}".format(referrer_fees)
    amount_left_hex = "{:064x}".format(amount - fees)
    print(f"{treasury_fees_hex}{referrer_fees_hex}{amount_left_hex}")


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--fees-bps", type=int
    )  # total fees in bps, to be split between treasury and referrer
    parser.add_argument("--referrer-fees-bps", type=int)  # fees given to referrer
    parser.add_argument("--amount", type=int)  # amount of tokens the user gets
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    main(args)
