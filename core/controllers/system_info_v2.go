package controllers

import (
    "github.com/crawlab-team/crawlab/core/entity"
    "github.com/gin-gonic/gin"
    "github.com/spf13/viper"
    "net/http"
)

func GetSystemInfo(c *gin.Context) {
    info := &entity.SystemInfo{
        Edition: viper.GetString("edition"),
        Version: viper.GetString("version"),
    }
    HandleSuccessWithData(c, info)
}

// GetVersion provides a lightweight version endpoint for frontend compatibility
// Some builds request '/api/version' which is rewritten to '/version' by nginx.
// Return plain text for maximum compatibility.
func GetVersion(c *gin.Context) {
    v := viper.GetString("version")
    c.String(http.StatusOK, v)
}
