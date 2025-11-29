// ==UserScript==
// @name         WHMCS 自动注册填充
// @namespace    http://tampermonkey.net/
// @version      2.0
// @description  专为 WHMCS 优化，使用 jQuery 触发事件，解决点击无反应问题。固定邮箱 mjj000008@outlook.com
// @author       Gemini
// @match        *://*/register.php*
// @match        *://*/client/register*
// @match        https://rarecloud.io/clients/register.php
// @grant        unsafeWindow
// ==/UserScript==

(function() {
    'use strict';

    // 配置信息
    const CONFIG = {
        email: "mjj000008@outlook.com",
        password: "214253551.Lxx",
        firstName: "See",
        lastName: "Player",
        company: "MJJ Studio",
        address1: "123 Virtual Street",
        city: "New York",
        state: "New York",
        postcode: "10001",
        phone: "2125550199"
    };

    // 核心填充功能
    function autoFill() {
        // 获取页面原生的 jQuery 对象
        var $ = unsafeWindow.jQuery;

        if (!$) {
            alert("错误：未检测到 jQuery，请确保页面完全加载后再点击。");
            return;
        }

        console.log("正在使用 jQuery 填充表单...");

        // 辅助函数：填充并触发所有必要的事件
        function fill(selector, value) {
            var el = $(selector);
            if (el.length) {
                // 聚焦 -> 设置值 -> 触发输入 -> 触发更改 -> 失去焦点 -> 触发键盘抬起(用于密码强度检测)
                el.focus().val(value).trigger('input').trigger('change').blur().trigger('keyup');
            }
        }

        // --- 1. 个人信息 ---
        fill('#inputFirstName', CONFIG.firstName);
        fill('#inputLastName', CONFIG.lastName);
        fill('#inputEmail', CONFIG.email);
        fill('#inputPhone', CONFIG.phone); // 针对 intl-tel-input

        // --- 2. 账单地址 ---
        fill('#inputCompanyName', CONFIG.company);
        fill('#inputAddress1', CONFIG.address1);
        fill('#inputCity', CONFIG.city);
        fill('#inputPostcode', CONFIG.postcode);

        // --- 3. 地区/省份 (WHMCS 特殊处理) ---
        // 先尝试在下拉框中找
        var stateSelect = $('#stateselect');
        if (stateSelect.is(':visible')) {
            // 模糊匹配选项文本
            stateSelect.find('option').each(function() {
                if ($(this).text().indexOf(CONFIG.state) !== -1) {
                    stateSelect.val($(this).val()).trigger('change');
                    return false; // break
                }
            });
        } else {
            // 如果下拉框不显示，说明是文本框输入模式
            fill('#stateinput', "NY");
        }

        // --- 4. 密码 (触发 keyup 以显示强度条) ---
        fill('#inputNewPassword1', CONFIG.password);
        fill('#inputNewPassword2', CONFIG.password);

        // --- 5. 条款勾选 ---
        // 尝试多种选择器以防万一
        var tos = $('input[name="accepttos"]');
        if (tos.length) {
            tos.prop('checked', true).trigger('change');
        }

        // 视觉反馈
        const btn = document.getElementById('mjj-fill-btn');
        if (btn) {
            btn.innerText = '✅ 填充完毕';
            setTimeout(() => { btn.innerText = '📝 一键填充 (MJJ)'; }, 2000);
        }
    }

    // 创建按钮
    function createButton() {
        if (document.getElementById('mjj-fill-btn')) return;

        const btn = document.createElement('button');
        btn.id = 'mjj-fill-btn';
        btn.innerHTML = '📝 一键填充 (MJJ)';
        btn.style.cssText = `
            position: fixed;
            top: 15%;
            right: 20px;
            z-index: 2147483647; /* 确保层级最高 */
            padding: 12px 20px;
            background-color: #e74c3c;
            color: white;
            border: 2px solid white;
            border-radius: 8px;
            cursor: pointer;
            box-shadow: 0 4px 10px rgba(0,0,0,0.3);
            font-weight: bold;
            font-size: 14px;
            transition: transform 0.1s;
        `;

        btn.onclick = function(e) {
            e.preventDefault();
            e.stopPropagation();
            // 添加点击特效
            btn.style.transform = 'scale(0.95)';
            setTimeout(() => btn.style.transform = 'scale(1)', 100);
            autoFill();
        };

        document.body.appendChild(btn);
    }

    // 延时加载，确保 jQuery 已就绪
    setTimeout(createButton, 1000);
    window.addEventListener('load', createButton);

})();