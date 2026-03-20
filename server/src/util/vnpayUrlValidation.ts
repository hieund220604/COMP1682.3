import net from 'node:net';

const LOCAL_HOSTS = new Set(['localhost', '127.0.0.1', '::1']);

const isPrivateIPv4 = (host: string): boolean => {
    const parts = host.split('.').map((part) => Number(part));
    if (parts.length !== 4 || parts.some((part) => Number.isNaN(part) || part < 0 || part > 255)) {
        return false;
    }

    const [a, b] = parts;
    return (
        a === 10 ||
        a === 127 ||
        (a === 172 && b >= 16 && b <= 31) ||
        (a === 192 && b === 168)
    );
};

const isPrivateHost = (host: string): boolean => {
    if (LOCAL_HOSTS.has(host.toLowerCase())) {
        return true;
    }

    const ipType = net.isIP(host);
    if (ipType === 4) {
        return isPrivateIPv4(host);
    }

    if (ipType === 6) {
        return host === '::1' || host.toLowerCase().startsWith('fc') || host.toLowerCase().startsWith('fd');
    }

    return false;
};

export const validateVNPayCallbackUrl = (url: string, envVarName: string): string => {
    const configuredUrl = url.trim();

    if (!configuredUrl) {
        throw new Error(`${envVarName} is required. This must be the approved URL in your VNPay merchant configuration.`);
    }

    let parsed: URL;
    try {
        parsed = new URL(configuredUrl);
    } catch {
        throw new Error(`${envVarName} is invalid. Please provide a valid absolute URL.`);
    }

    if (parsed.hostname.includes('vnpayment.vn')) {
        throw new Error(`${envVarName} must be your merchant callback URL, not a VNPay URL.`);
    }

    const allowInsecure =
        process.env.VNPAY_ALLOW_INSECURE_CALLBACK_URL === 'true' ||
        process.env.VNPAY_ALLOW_LOCAL_RETURN_URL === 'true';
    if (parsed.protocol !== 'https:' && !allowInsecure) {
        throw new Error(`${envVarName} must use HTTPS. Set VNPAY_ALLOW_INSECURE_CALLBACK_URL=true only for local debugging.`);
    }

    if (isPrivateHost(parsed.hostname) && !allowInsecure) {
        throw new Error(`${envVarName} must be a public host accessible from VNPay. Private/LAN hosts are not allowed.`);
    }

    return configuredUrl;
};
