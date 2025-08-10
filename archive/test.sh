#!/bin/bash

# WatchScroller 测试脚本
# 用于验证应用功能和性能

set -e

echo "🧪 WatchScroller 测试开始..."

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 测试结果统计
TESTS_PASSED=0
TESTS_FAILED=0

# 辅助函数
print_status() {
    case $1 in
        "PASS")
            echo -e "${GREEN}✅ PASS${NC}: $2"
            ((TESTS_PASSED++))
            ;;
        "FAIL")
            echo -e "${RED}❌ FAIL${NC}: $2"
            ((TESTS_FAILED++))
            ;;
        "INFO")
            echo -e "${BLUE}ℹ️  INFO${NC}: $2"
            ;;
        "WARN")
            echo -e "${YELLOW}⚠️  WARN${NC}: $2"
            ;;
    esac
}

# 1. 检查项目结构
test_project_structure() {
    print_status "INFO" "检查项目结构..."
    
    # 检查关键目录
    local dirs=("macOS-App" "WatchOS-App" "Research" "Documentation" "Assets")
    for dir in "${dirs[@]}"; do
        if [ -d "$dir" ]; then
            print_status "PASS" "目录 $dir 存在"
        else
            print_status "FAIL" "目录 $dir 不存在"
        fi
    done
    
    # 检查关键文件
    local files=("README.md" "Documentation/USER_GUIDE.md" "Documentation/BUILD_INSTRUCTIONS.md")
    for file in "${files[@]}"; do
        if [ -f "$file" ]; then
            print_status "PASS" "文件 $file 存在"
        else
            print_status "FAIL" "文件 $file 不存在"
        fi
    done
}

# 2. 检查 macOS 项目配置
test_macos_project() {
    print_status "INFO" "检查 macOS 项目配置..."
    
    local mac_project="macOS-App/WatchScroller.xcodeproj/project.pbxproj"
    if [ -f "$mac_project" ]; then
        print_status "PASS" "macOS Xcode 项目文件存在"
        
        # 检查关键 Swift 文件
        local swift_files=(
            "macOS-App/WatchScroller/AppDelegate.swift"
            "macOS-App/WatchScroller/Views/ContentView.swift"
            "macOS-App/WatchScroller/Controllers/ScrollController.swift"
            "macOS-App/WatchScroller/Controllers/WatchConnectivityManager.swift"
        )
        
        for file in "${swift_files[@]}"; do
            if [ -f "$file" ]; then
                print_status "PASS" "Swift 文件 $(basename $file) 存在"
            else
                print_status "FAIL" "Swift 文件 $(basename $file) 不存在"
            fi
        done
        
        # 检查配置文件
        local config_files=(
            "macOS-App/WatchScroller/Info.plist"
            "macOS-App/WatchScroller/WatchScroller.entitlements"
        )
        
        for file in "${config_files[@]}"; do
            if [ -f "$file" ]; then
                print_status "PASS" "配置文件 $(basename $file) 存在"
            else
                print_status "FAIL" "配置文件 $(basename $file) 不存在"
            fi
        done
    else
        print_status "FAIL" "macOS Xcode 项目文件不存在"
    fi
}

# 3. 检查 watchOS 项目配置
test_watchos_project() {
    print_status "INFO" "检查 watchOS 项目配置..."
    
    local watch_project="WatchOS-App/WatchScrollerWatch.xcodeproj/project.pbxproj"
    if [ -f "$watch_project" ]; then
        print_status "PASS" "watchOS Xcode 项目文件存在"
        
        # 检查关键 Swift 文件
        local swift_files=(
            "WatchOS-App/WatchScrollerWatch/WatchScrollerWatchApp.swift"
            "WatchOS-App/WatchScrollerWatch/Views/ContentView.swift"
            "WatchOS-App/WatchScrollerWatch/Controllers/WatchConnectivityManager.swift"
        )
        
        for file in "${swift_files[@]}"; do
            if [ -f "$file" ]; then
                print_status "PASS" "Swift 文件 $(basename $file) 存在"
            else
                print_status "FAIL" "Swift 文件 $(basename $file) 不存在"
            fi
        done
        
        # 检查配置文件
        if [ -f "WatchOS-App/WatchScrollerWatch/Info.plist" ]; then
            print_status "PASS" "watchOS Info.plist 存在"
        else
            print_status "FAIL" "watchOS Info.plist 不存在"
        fi
    else
        print_status "FAIL" "watchOS Xcode 项目文件不存在"
    fi
}

# 4. 代码质量检查
test_code_quality() {
    print_status "INFO" "进行代码质量检查..."
    
    # 检查 Swift 代码语法（如果有 swiftlint）
    if command -v swiftlint &> /dev/null; then
        print_status "INFO" "运行 SwiftLint 检查..."
        if swiftlint --quiet; then
            print_status "PASS" "SwiftLint 检查通过"
        else
            print_status "WARN" "SwiftLint 发现了一些问题"
        fi
    else
        print_status "INFO" "SwiftLint 未安装，跳过代码风格检查"
    fi
    
    # 检查 TODO 和 FIXME
    local todo_count=$(find . -name "*.swift" -exec grep -l "TODO\|FIXME" {} \; | wc -l)
    if [ $todo_count -gt 0 ]; then
        print_status "INFO" "发现 $todo_count 个文件包含 TODO/FIXME"
        find . -name "*.swift" -exec grep -n "TODO\|FIXME" {} +
    else
        print_status "PASS" "没有发现待办事项标记"
    fi
}

# 5. 编译测试 (如果 Xcode 可用)
test_compilation() {
    print_status "INFO" "测试项目编译..."
    
    if command -v xcodebuild &> /dev/null; then
        # 测试 macOS 项目编译
        cd macOS-App
        if xcodebuild -project WatchScroller.xcodeproj -scheme WatchScroller -configuration Debug -quiet clean build; then
            print_status "PASS" "macOS 项目编译成功"
        else
            print_status "FAIL" "macOS 项目编译失败"
        fi
        cd ..
        
        # 测试 watchOS 项目编译（使用模拟器）
        cd WatchOS-App
        if xcodebuild -project WatchScrollerWatch.xcodeproj -scheme WatchScrollerWatch -configuration Debug -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' -quiet clean build; then
            print_status "PASS" "watchOS 项目编译成功"
        else
            print_status "FAIL" "watchOS 项目编译失败"
        fi
        cd ..
    else
        print_status "WARN" "Xcode 命令行工具不可用，跳过编译测试"
    fi
}

# 6. 文档完整性检查
test_documentation() {
    print_status "INFO" "检查文档完整性..."
    
    # 检查 README
    if [ -f "README.md" ]; then
        if grep -q "WatchScroller" README.md; then
            print_status "PASS" "README 包含项目信息"
        else
            print_status "FAIL" "README 缺少项目信息"
        fi
    fi
    
    # 检查用户指南
    if [ -f "Documentation/USER_GUIDE.md" ]; then
        local required_sections=("安装步骤" "基本使用" "故障排除")
        for section in "${required_sections[@]}"; do
            if grep -q "$section" "Documentation/USER_GUIDE.md"; then
                print_status "PASS" "用户指南包含 '$section' 部分"
            else
                print_status "FAIL" "用户指南缺少 '$section' 部分"
            fi
        done
    fi
    
    # 检查构建说明
    if [ -f "Documentation/BUILD_INSTRUCTIONS.md" ]; then
        if grep -q "构建步骤" "Documentation/BUILD_INSTRUCTIONS.md"; then
            print_status "PASS" "构建说明文档存在"
        else
            print_status "FAIL" "构建说明文档内容不完整"
        fi
    fi
}

# 7. 依赖和系统要求检查
test_requirements() {
    print_status "INFO" "检查系统要求..."
    
    # 检查 macOS 版本
    local macos_version=$(sw_vers -productVersion)
    print_status "INFO" "当前 macOS 版本: $macos_version"
    
    # 检查 Xcode
    if command -v xcodebuild &> /dev/null; then
        local xcode_version=$(xcodebuild -version | head -n 1)
        print_status "PASS" "$xcode_version 已安装"
    else
        print_status "FAIL" "Xcode 命令行工具未安装"
    fi
    
    # 检查 Swift
    if command -v swift &> /dev/null; then
        local swift_version=$(swift --version | head -n 1)
        print_status "PASS" "$swift_version"
    else
        print_status "FAIL" "Swift 编译器不可用"
    fi
}

# 8. 性能和资源检查
test_performance() {
    print_status "INFO" "性能和资源检查..."
    
    # 检查代码行数
    local swift_lines=$(find . -name "*.swift" -exec wc -l {} + | tail -n 1 | awk '{print $1}')
    print_status "INFO" "Swift 代码总行数: $swift_lines"
    
    # 检查项目大小
    local project_size=$(du -sh . | awk '{print $1}')
    print_status "INFO" "项目总大小: $project_size"
    
    # 检查大文件
    local large_files=$(find . -size +1M -type f | wc -l)
    if [ $large_files -gt 0 ]; then
        print_status "WARN" "发现 $large_files 个大于 1MB 的文件"
        find . -size +1M -type f -exec ls -lh {} +
    else
        print_status "PASS" "没有发现异常大的文件"
    fi
}

# 运行所有测试
main() {
    echo "🚀 开始 WatchScroller 项目测试"
    echo "================================="
    
    test_project_structure
    echo ""
    
    test_macos_project
    echo ""
    
    test_watchos_project
    echo ""
    
    test_code_quality
    echo ""
    
    test_compilation
    echo ""
    
    test_documentation
    echo ""
    
    test_requirements
    echo ""
    
    test_performance
    echo ""
    
    # 测试总结
    echo "================================="
    echo "📊 测试结果总结:"
    echo -e "${GREEN}通过: $TESTS_PASSED${NC}"
    echo -e "${RED}失败: $TESTS_FAILED${NC}"
    
    local total_tests=$((TESTS_PASSED + TESTS_FAILED))
    if [ $total_tests -gt 0 ]; then
        local success_rate=$((TESTS_PASSED * 100 / total_tests))
        echo "成功率: $success_rate%"
    fi
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}🎉 所有测试通过！项目状态良好。${NC}"
        exit 0
    else
        echo -e "${RED}⚠️  有 $TESTS_FAILED 个测试失败，请检查上述问题。${NC}"
        exit 1
    fi
}

# 运行主函数
main