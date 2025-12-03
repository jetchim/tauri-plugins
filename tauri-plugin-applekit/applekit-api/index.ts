import {invoke as tauri_invoke} from '@tauri-apps/api/core'

/**
 * set key/value to apple UserDefault
 * @param key
 * @param value
 */
export async function set(key: string, value: string): Promise<void> {
    return await invoke('set_user_default', {
        key: key,
        value: value
    }).then(r => r)
}

export async function get(key: string): Promise<string | null> {
    return await invoke('get_user_default', {
        key: key
    }).then(r => r)
}

export async function setTheme(theme: string): Promise<void> {
    return await invoke('set_theme', {
        theme: theme
    }).then(_ => {
    })
}

export async function showHUD(label: string): Promise<void> {
    return await invoke('show_hud', {
        label: label
    }).then(_ => {
    })
}

export async function hideHUD(label: string): Promise<void> {
    return await invoke('close_hud', {
        label: label
    }).then(_ => {
    })
}

async function invoke(cmd: string, params: any): Promise<any> {
    return await tauri_invoke<any>(`plugin:applekit|${cmd}`, params).then(r => r)
}
