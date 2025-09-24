// SPDX-License-Identifier: UNLICENSED
// Created for Soonami Venturethon prototype only.
// No redistribution, modification, or commercial use without prior written consent.
// Copyright (c) 2025 Patrick Fischer. All rights reserved.
pragma solidity 0.8.24;

import '../manager/GildiManager.sol';
import './MockUpgrade.sol';

contract MockGildiManagerUpgrade is GildiManager, MockUpgrade {}
