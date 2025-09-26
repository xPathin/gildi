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
        11155420: "0xe6A3d2959974A47a6CaaC9a5a899324DEEa0e0c0", // OP Testnet
    },
    [Token.USDC]: {
        11155420: "0x23Bd327a5C8f5D7bb9A7854985Bacf93fbb739Ec", // OP Testnet
    },
    [Token.WNATIVE]: {
        11155420: "0x44dF2B9818CBFA04CF3f5aa916CE39De9d8E32bB", // OP Testnet
    },
    [Token.WETH]: {
        11155420: "0x44dF2B9818CBFA04CF3f5aa916CE39De9d8E32bB", // OP Testnet
    },
};
