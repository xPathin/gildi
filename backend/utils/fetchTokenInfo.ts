import { Token, tokenAddresses } from "../constants/tokenAddresses";

export function fetchTokenAddress(token: Token, chainId: number): string {
    const tokenAddressKeyValuePairs = Object.entries(tokenAddresses);
    let address: string | undefined;
    for (const [key, value] of tokenAddressKeyValuePairs) {
        const enumKey = Token[key as keyof typeof Token];
        if (enumKey == token || parseInt(key) == token) {
            address = value[chainId];
            break;
        }
    }

    if (!address) {
        throw new Error(`Token address not found for token ${Token[token]} on chain ${chainId}`);
    }

    return address;
}

export function fetchTokenAddressOrNull(token: Token, chainId: number): string | null {
    const address = tokenAddresses[token]?.[chainId];
    if (!address) {
        return null;
    }

    return address;
}

export function resolveTokenEnumByName(tokenName: string): Token {
    const allTokenKeys = Object.keys(Token).filter(key => isNaN(Number(key)));
    const tokenKvps = allTokenKeys.map(key => ({ key, value: Token[key as keyof typeof Token] }));

    for (const kvp of tokenKvps) {
        if (kvp.key.toLowerCase() === tokenName.toLowerCase()) {
            return kvp.value;
        }
    }

    throw new Error(`Token enum not found for token name ${tokenName}`);
}

export function resolveTokenByAddress(address: string, chainId: number): Token | null {
    const allTokenKeys = Object.keys(Token).filter(key => isNaN(Number(key)));
    const tokenKvps = allTokenKeys.map(key => ({ key, value: Token[key as keyof typeof Token] }));

    for (const kvp of tokenKvps) {
        if (tokenAddresses[kvp.value][chainId] === address) {
            return kvp.value;
        }
    }

    return null;
}

export function resolveTokenNameByAddress(address: string, chainId: number): string | null {
    for (const token in tokenAddresses) {
        const tokenEnum = Token[token as keyof typeof Token];
        if (tokenAddresses[tokenEnum][chainId] === address) {
            return token;
        }
    }
    return null;
}