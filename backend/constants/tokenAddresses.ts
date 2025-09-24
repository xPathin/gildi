export enum Token {
    RUST,
    USDC,
    WNATIVE,
    WETH,
}

export interface ITokenAddress {
    [chainId: number]: string | undefined;
}

export const tokenAddresses: { [token in Token]: ITokenAddress } = {
    [Token.RUST]: {
        11155420: "0x816E47EBef59430fd97EC347C744c8119193806E", // OP Testnet
    },
    [Token.USDC]: {
        11155420: "0xF6fCB430A407f7f53DB4515e05313C41Dc088488", // OP Testnet
    },
    [Token.WNATIVE]: {
        11155420: "0xa67223FF152f9ad1800D74d2314D08E6B575690E", // OP Testnet
    },
    [Token.WETH]: {
        11155420: "0xa67223FF152f9ad1800D74d2314D08E6B575690E", // OP Testnet
    },
};
