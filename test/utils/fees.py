import argparse

def main(args):
    fees_bps = args.fees_bps
    amount = args.amount

    if fees_bps is None or amount is None:
        print("Both --fees-bps and --amount arguments are required.")
        return

    fees = int((amount * fees_bps) / 10000)
    fees_hex = "0x{:064x}".format(fees)
    amount_left_hex = "{:064x}".format(amount - fees)
    print(f"{fees_hex}{amount_left_hex}")

def parse_args(): 
    parser = argparse.ArgumentParser()
    parser.add_argument("--fees-bps", type=int)
    parser.add_argument("--amount", type=int)
    return parser.parse_args()


if __name__ == '__main__':
    args = parse_args() 
    main(args)